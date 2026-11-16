/*
  Compact stepper turntable - firmware for Arduino Uno + CNC Shield V3
  Drawing CPI-TT-002. Motor on the X slot (DRV8825 or TMC2209, 1/32 microstepping).

  Serial 115200 baud, one command per line:
    V <deg/s>                 continuous rotation (signed). V 0 = ramp down and stop
    M <deg>                   relative move
    A <deg>                   absolute move (to angle from zero)
    I <step_deg> <dwell_ms> <count> [settle_ms]
                              index mode: move step, settle, dwell, repeat.
                              count 0 = until S. settle defaults to 300 ms
    S                         stop (ramped)      X  stop now (no ramp)
    H                         home on the optical endstop, then zero there
    Z                         set current position as zero
    P                         print position
    R <deg/s>                 max speed for moves      (default 20 deg/s)
    C <deg/s^2>               acceleration             (default 40 deg/s^2)
    E <0|1>                   driver disable / enable
  Radial axis (optional, motor on the Y slot). Only moves while the turntable is stopped:
    Y <mm>                    relative radial move (+ = toward the spindle)
    W <mm/s>                  radial speed             (default 1 mm/s)
    K                         set current radial position as zero
    Q                         print radial position
  Every line it sends starts with a tag, comma separated, times in ms (millis):
    OK,<cmd>                  command accepted
    MV,<t>,<pos_steps>        a move started
    DW,<t>,<pos_steps>,<n>    index n reached; dwell starts now (take frames here)
    DN,<t>,<pos_steps>        motion finished
    POS,<t>,<pos_steps>,<deg>
    HOME,<t>,<ok|fail>
    RD,<t>,<rad_steps>,<mm>   a radial move finished (also the reply to Q)
    ERR,<text>
  Log these lines on the PC alongside the video: DW lines give theta for every dwell.
*/

#include <Arduino.h>

// ---------------- hardware ----------------
const uint8_t PIN_STEP = 2;    // X STEP  (PD2)
const uint8_t PIN_DIR  = 5;    // X DIR   (PD5)
const uint8_t PIN_EN   = 8;    // all drivers, active LOW
const uint8_t PIN_HOME = 9;    // X- limit header
const bool    HOME_ACTIVE_HIGH = true;   // most slotted optical endstops: HIGH when blocked
const bool    DIR_INVERT = false;        // flip if + angles turn clockwise seen from above
const uint8_t PIN_YSTEP = 3;   // Y STEP  (radial axis)
const uint8_t PIN_YDIR  = 6;   // Y DIR
const bool    RAD_DIR_INVERT = false;    // flip if + mm moves away from the spindle

// ---------------- mechanics ----------------
const long  MOTOR_STEPS = 200;
const long  MICROSTEPS  = 32;
const long  RATIO       = 4;              // GT2 80T / 20T
const long  STEPS_PER_REV = MOTOR_STEPS * MICROSTEPS * RATIO;   // 25600
const float STEPS_PER_DEG = STEPS_PER_REV / 360.0f;             // 71.11
// Radial axis: SET THIS for your screw or belt. 200 full steps x 32 microsteps
// per motor turn, divided by the travel per motor turn in mm.
// Example: a lead screw with 8 mm lead gives 6400 / 8 = 800.
const float RAD_STEPS_PER_MM = 800.0f;

// ---------------- motion state (shared with ISR) ----------------
volatile long  pos = 0;            // steps, + = counter-clockwise
volatile long  remaining = 0;      // steps left in a move (ignored when continuous)
volatile bool  continuous = false;
volatile int8_t dirSign = 1;
volatile bool  running = false;

float vmax  = 20.0f * STEPS_PER_DEG;   // steps/s
float accel = 40.0f * STEPS_PER_DEG;   // steps/s^2
float v = 0;                            // current speed, steps/s (>=0)
float vTarget = 0;                      // continuous mode target (signed sign in dirSign)
bool  stopping = false;
bool  moveActive = false;               // a position move is in progress

// index mode
bool  idxActive = false;
long  idxStep = 0, idxCount = 0, idxDone = 0;
unsigned long idxSettle = 300, idxDwell = 500, idxT0 = 0;
enum IdxPhase { IDX_MOVE, IDX_SETTLE, IDX_DWELL } idxPhase = IDX_MOVE;

// radial axis (moved by a simple blocking loop; the turntable is at rest then)
long  radPos = 0;                       // steps, + = toward the spindle
float radSpeed = 1.0f;                  // mm/s

// homing
bool homing = false;
unsigned long homeT0 = 0;

// ---------------- step timer (Timer1, CTC) ----------------
void timerSetRate(float rate) {
  if (rate < 1.0f) { TIMSK1 &= ~_BV(OCIE1A); running = false; return; }
  uint8_t cs; float tick;
  if (rate >= 40.0f) { cs = _BV(CS11); tick = 2000000.0f; }            // /8
  else               { cs = _BV(CS11) | _BV(CS10); tick = 250000.0f; } // /64
  unsigned long ocr = (unsigned long)(tick / rate) - 1;
  if (ocr > 65535UL) ocr = 65535UL;
  if (ocr < 99) ocr = 99;                                               // <= 20 k steps/s
  noInterrupts();
  TCCR1B = _BV(WGM12) | cs;
  OCR1A = (uint16_t)ocr;
  if (TCNT1 > OCR1A) TCNT1 = 0;
  TIMSK1 |= _BV(OCIE1A);
  running = true;
  interrupts();
}

ISR(TIMER1_COMPA_vect) {
  if (!continuous && remaining <= 0) { TIMSK1 &= ~_BV(OCIE1A); running = false; return; }
  PORTD |= _BV(PD2);
  pos += dirSign;
  if (!continuous) remaining--;
  delayMicroseconds(2);              // DRV8825 needs >= 1.9 us high
  PORTD &= ~_BV(PD2);
}

void setDir(int8_t s) {
  dirSign = s;
  bool level = (s > 0) ^ DIR_INVERT;
  digitalWrite(PIN_DIR, level ? HIGH : LOW);
  delayMicroseconds(5);              // DIR setup time before the next step
}

// ---------------- motion commands ----------------
void startMove(long steps) {
  if (steps == 0) { report("DN"); return; }
  noInterrupts(); continuous = false; remaining = labs(steps); interrupts();
  setDir(steps > 0 ? 1 : -1);
  stopping = false;
  moveActive = true;
  v = max(v, 20.0f);
  timerSetRate(v);
  report("MV");
}

void startContinuous(float degps) {
  if (degps == 0) { stopping = true; return; }
  int8_t s = degps > 0 ? 1 : -1;
  if (running && s != dirSign) {    // reversing: ramp down first, then restart
    stopping = true; vTarget = 0; return;
  }
  noInterrupts(); continuous = true; interrupts();
  setDir(s);
  vTarget = fabs(degps) * STEPS_PER_DEG;
  stopping = false;
  if (!running) { v = 20.0f; timerSetRate(v); report("MV"); }
}

void hardStop() {
  TIMSK1 &= ~_BV(OCIE1A);
  noInterrupts(); running = false; remaining = 0; continuous = false; interrupts();
  v = 0; stopping = false; idxActive = false; homing = false; moveActive = false;
}

// called every 1 ms: trapezoidal ramp
void updateRamp(float dt) {
  if (!running) { v = 0; return; }
  float target;
  if (continuous) {
    target = stopping ? 0 : vTarget;
  } else {
    long rem; noInterrupts(); rem = remaining; interrupts();
    float vStop = sqrtf(2.0f * accel * (float)rem);     // speed that still stops in time
    target = stopping ? 0 : min(vmax, vStop);
  }
  if (v < target) v = min(target, v + accel * dt);
  else            v = max(target, v - accel * dt);
  if (v < 20.0f) {
    if ((continuous || stopping) && target == 0) {     // ramped stop complete
      hardStop(); report("DN"); return;
    }
    v = 20.0f;                                         // crawl to the last steps
  }
  timerSetRate(v);
}

// ---------------- radial axis ----------------
void reportRadial() {
  Serial.print(F("RD,")); Serial.print(millis()); Serial.print(',');
  Serial.print(radPos); Serial.print(','); Serial.println(radPos / RAD_STEPS_PER_MM, 4);
}

// Relative move with a short ramp at both ends. Blocks until done; an X on
// the serial line aborts it.
void radialMove(float mm) {
  long steps = lroundf(mm * RAD_STEPS_PER_MM);
  long n = labs(steps);
  int8_t s = steps >= 0 ? 1 : -1;
  digitalWrite(PIN_YDIR, ((s > 0) ^ RAD_DIR_INVERT) ? HIGH : LOW);
  delayMicroseconds(5);
  float rate = radSpeed * RAD_STEPS_PER_MM;            // steps/s at full speed
  if (rate < 10.0f) rate = 10.0f;
  if (rate > 8000.0f) rate = 8000.0f;
  const long RAMP = 200;                               // steps of ramp at each end
  for (long i = 0; i < n; i++) {
    if (Serial.peek() == 'X' || Serial.peek() == 'x') break;
    long edge = min(i, n - 1 - i);                     // distance to the nearer end
    float r = edge < RAMP ? rate * (0.25f + 0.75f * edge / RAMP) : rate;
    unsigned long interval = (unsigned long)(1000000.0f / r);
    digitalWrite(PIN_YSTEP, HIGH);
    delayMicroseconds(3);                              // DRV8825 needs >= 1.9 us high
    digitalWrite(PIN_YSTEP, LOW);
    radPos += s;
    if (interval > 16000UL) { delay(interval / 1000UL); delayMicroseconds(interval % 1000UL); }
    else delayMicroseconds(interval);
  }
  reportRadial();
}

// ---------------- reporting ----------------
long readPos() { long p; noInterrupts(); p = pos; interrupts(); return p; }

void report(const char *tag) {
  Serial.print(tag); Serial.print(','); Serial.print(millis());
  Serial.print(','); Serial.println(readPos());
}

// ---------------- command parser ----------------
char buf[64]; uint8_t blen = 0;

void handle(char *line) {
  char c = toupper(line[0]);
  char *args = line + 1;
  float a = 0, b = 0, d = 0, e = 0;
  int n = sscanf_floats(args, &a, &b, &d, &e);
  switch (c) {
    case 'V': startContinuous(a); break;
    case 'M': idxActive = false; startMove(lroundf(a * STEPS_PER_DEG)); break;
    case 'A': idxActive = false; startMove(lroundf(a * STEPS_PER_DEG) - readPos()); break;
    case 'I':
      if (n < 3) { Serial.println(F("ERR,I needs step_deg dwell_ms count")); return; }
      idxStep = lroundf(a * STEPS_PER_DEG); idxDwell = (unsigned long)b;
      idxCount = (long)d; idxSettle = n >= 4 ? (unsigned long)e : 300;
      idxDone = 0; idxActive = true; idxPhase = IDX_MOVE; startMove(idxStep);
      break;
    case 'S': idxActive = false; homing = false; stopping = true; break;
    case 'X': hardStop(); report("DN"); break;
    case 'H': idxActive = false; homing = true; homeT0 = millis(); startContinuous(5.0f); break;
    case 'Z': noInterrupts(); pos = 0; interrupts(); break;
    case 'P': {
      long p = readPos();
      Serial.print(F("POS,")); Serial.print(millis()); Serial.print(',');
      Serial.print(p); Serial.print(','); Serial.println(p / STEPS_PER_DEG, 4);
      return; }
    case 'R': if (a > 0) vmax = a * STEPS_PER_DEG; break;
    case 'C': if (a > 0) accel = a * STEPS_PER_DEG; break;
    case 'E': digitalWrite(PIN_EN, a > 0 ? LOW : HIGH); break;
    case 'Y':
      if (running) { Serial.println(F("ERR,stop the turntable before a radial move")); return; }
      radialMove(a); break;
    case 'W': if (a > 0) radSpeed = a; break;
    case 'K': radPos = 0; break;
    case 'Q': reportRadial(); return;
    default: Serial.println(F("ERR,unknown command")); return;
  }
  Serial.print(F("OK,")); Serial.println(c);
}

// minimal float parser (avoids pulling in full scanf float support)
int sscanf_floats(char *s, float *a, float *b, float *c, float *d) {
  float *out[4] = {a, b, c, d}; int n = 0;
  while (*s && n < 4) {
    while (*s == ' ' || *s == ',' || *s == '\t') s++;
    if (!*s) break;
    char *end; double val = strtod(s, &end);
    if (end == s) break;
    *out[n++] = (float)val; s = end;
  }
  return n;
}

bool homeSensor() {
  bool hi = digitalRead(PIN_HOME) == HIGH;
  return HOME_ACTIVE_HIGH ? hi : !hi;
}

// ---------------- setup / loop ----------------
void setup() {
  pinMode(PIN_STEP, OUTPUT); pinMode(PIN_DIR, OUTPUT);
  pinMode(PIN_YSTEP, OUTPUT); pinMode(PIN_YDIR, OUTPUT);
  pinMode(PIN_EN, OUTPUT); digitalWrite(PIN_EN, LOW);   // enable drivers
  pinMode(PIN_HOME, INPUT_PULLUP);
  TCCR1A = 0; TCCR1B = 0; TIMSK1 = 0;
  Serial.begin(115200);
  Serial.print(F("READY,")); Serial.print(STEPS_PER_REV); Serial.println(F(",steps/rev"));
}

void loop() {
  static unsigned long tPrev = micros();
  unsigned long now = micros();
  if (now - tPrev >= 1000) {
    float dt = (now - tPrev) * 1e-6f; tPrev = now;
    updateRamp(dt);
    // a position move that ran out of steps
    if (moveActive && !running) { moveActive = false; v = 0; if (!idxActive) report("DN"); }
  }

  // index mode state machine
  if (idxActive && !running) {
    unsigned long t = millis();
    if (idxPhase == IDX_MOVE) { idxPhase = IDX_SETTLE; idxT0 = t; }
    else if (idxPhase == IDX_SETTLE && t - idxT0 >= idxSettle) {
      idxPhase = IDX_DWELL; idxT0 = t; idxDone++;
      Serial.print(F("DW,")); Serial.print(t); Serial.print(',');
      Serial.print(readPos()); Serial.print(','); Serial.println(idxDone);
    }
    else if (idxPhase == IDX_DWELL && t - idxT0 >= idxDwell) {
      if (idxCount > 0 && idxDone >= idxCount) { idxActive = false; report("DN"); }
      else { idxPhase = IDX_MOVE; startMove(idxStep); }
    }
  }

  // homing: run slowly until the flag enters the sensor
  if (homing) {
    if (homeSensor()) {
      hardStop(); noInterrupts(); pos = 0; interrupts();
      Serial.print(F("HOME,")); Serial.print(millis()); Serial.println(F(",ok"));
    } else if (millis() - homeT0 > 90000UL) {     // > 1.25 rev at 5 deg/s
      hardStop(); Serial.print(F("HOME,")); Serial.print(millis()); Serial.println(F(",fail"));
    }
  }

  // serial input
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (blen) { buf[blen] = 0; handle(buf); blen = 0; }
    } else if (blen < sizeof(buf) - 1) buf[blen++] = ch;
  }
}
