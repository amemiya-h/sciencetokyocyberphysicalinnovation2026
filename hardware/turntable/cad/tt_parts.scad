// Compact stepper turntable - printed parts (matches drawing CPI-TT-001 rev E)
// Layout after the Audio-Technica Sound Burger: narrow chassis, small platter,
// record overhangs. Units mm, origin = shaft axis on the chassis underside.
//
// Printer: Bambu Lab P1S (256 mm cube), PETG, 0.4 nozzle, 0.2 mm layers,
// 4 walls, 40 % gyroid (chassis 60 %). Every part prints in the orientation it
// is modelled in, without supports: see the PRINT NOTES at each module.
// Export one part at a time:
//   openscad -D 'part="chassis"' -o chassis.stl tt_parts.scad
// parts: "chassis", "platter", "spindle", "flag", "clamp", "collar", "pulley80", "pulley20",
//        "foot", "sensor_post", "skid_arm", "cover", "all"
// Rev E: everything printable is printed. Both GT2 pulleys, the shaft collar and the
// platter hub (replaces the flange coupler) are printed; the shims are bosses on the
// collar and the 80T hub; feet are TPU (or PETG). Bought: 608ZZ x2, shaft, belt, screws.
// Rev E also fixes the bottom bearing bore: it is now open from below at the seat
// diameter, so the bearing presses up against the cone shoulder.
// Rev D: +x end has an 8 mm pad with 2 x M5 (x = 26, 36): the interface for the
// optional skid arm now and the radial-axis spine later.
// Electronics tray on the +y side carries the Uno + CNC shield under a vented cover
// (all under the record overhang, far corner 118 mm from the axis).

part = "all";
$fn = 96;

// ---------------- fits (tune to your printer) ----------------
brg_seat_d = 22.15;   // 608ZZ OD 22, light press fit
pilot_d    = 23.0;    // NEMA17 pilot boss 22
spindle_d  = 7.1;     // record centre hole 7.24
shaft_fit  = 8.15;    // printed hubs on the 8 mm shaft (set screw takes up the rest)
motor_fit  = 5.15;    // 20T pulley on the 5 mm motor shaft (D-flat)
pin_fit    = 5.0;     // spindle pin press fit in the platter
m3 = 3.4;  m4 = 4.5;  m5 = 5.5;

// ---------------- key geometry ----------------
MX      = -46;        // motor axis x (GT2 20T/80T, 200 mm belt)
DECK_Z  = 40;         // motor face (deck underside)
DECK_T  = 6;
BASE_T  = 4;
HOUSE_R = 18;
HOUSE_H = 50;         // bearing housing top
SEAT_LO = 8;          // bottom 608ZZ  z 8..15
SEAT_HI = 43;         // top 608ZZ     z 43..50
PLAT_Z  = 78;         // platter underside

// ---------------- electronics tray (Uno R3 + CNC shield V3) ----------------
UNO_X = -70;  UNO_Y = 34;              // board's lower-left corner; USB/DC jack face -x
UNO_HOLES = [[13.97, 2.54], [15.24, 50.8], [66.04, 7.62], [66.04, 35.56]];
COVER_TABS_Y = [40, 82];

// ---------------- cosmetic edges ----------------
EF = 0.5;             // bed-edge chamfer (also hides elephant's foot)
CT = 1.0;             // top-edge chamfer

// Box with rounded vertical edges (radius r), a chamfer cb on its bottom edges and
// ct on its top edges. p = min corner, s = size.
module rbox(p, s, r = 3, cb = EF, ct = CT) {
    translate(p) hull()
        for (x = [r, s[0] - r], y = [r, s[1] - r]) translate([x, y, 0]) {
            cylinder(r1 = r - cb, r2 = r, h = cb + 0.001);
            translate([0, 0, cb]) cylinder(r = r, h = s[2] - cb - ct);
            translate([0, 0, s[2] - ct - 0.001]) cylinder(r1 = r, r2 = r - ct, h = ct + 0.001);
        }
}

// Cylinder with a chamfer cb on the bottom edge and ct on the top edge.
module ccyl(d, h, cb = EF, ct = CT) {
    cylinder(d1 = d - 2 * cb, d2 = d, h = cb + 0.001);
    translate([0, 0, cb]) cylinder(d = d, h = h - cb - ct);
    translate([0, 0, h - ct - 0.001]) cylinder(d1 = d, d2 = d - 2 * ct, h = ct + 0.001);
}

// Hole with a small entry chamfer on the top face (z = ztop).
module chole(d, z0, ztop, c = 0.6) {
    translate([0, 0, z0]) cylinder(d = d, h = ztop - z0 + 0.01);
    translate([0, 0, ztop - c]) cylinder(d1 = d, d2 = d + 2 * c + 0.02, h = c + 0.01);
}

// ================= chassis (part 1) =================
// PRINT NOTES: base on the bed as modelled. The deck bridges 44 mm between the
// side walls over the motor window (fine on a P1S; enable "thick bridges").
// The bottom bearing seat ends in a 45 deg cone instead of a flat ceiling, so
// nothing overhangs there; the cone still locates the outer ring.
module chassis() {
    difference() {
        union() {
            // base plate 116 x 80, plus the electronics tray on the +y side
            rbox([-76, -40, 0], [116, 80, BASE_T], r = 4, cb = EF, ct = 0.6);
            rbox([-76, 20, 0], [84, 79, BASE_T], r = 4, cb = EF, ct = 0.6);
            // Uno standoffs, 6 mm (board underside at z 10)
            for (h = UNO_HOLES) translate([UNO_X + h[0], UNO_Y + h[1], 0]) ccyl(6.5, BASE_T + 6, cb = 0.01, ct = 0.5);
            // motor block: side walls + end wall + deck in one rounded shell
            difference() {
                rbox([-76, -28, 0], [76, 56, DECK_Z + DECK_T], r = 3, cb = EF, ct = CT);
                translate([-70, -22, -1]) cube([71, 44, DECK_Z + 1]);   // open toward +x
            }
            // bearing housing
            ccyl(2 * HOUSE_R, HOUSE_H, cb = EF, ct = CT);
            // interface pad at the +x end, 8 mm, 2 x M5
            rbox([12, -14, 0], [28, 28, 8], r = 3, cb = EF, ct = CT);
        }
        // ---- bearing bores
        translate([0, 0, -1]) cylinder(d = brg_seat_d, h = SEAT_LO + 8.01);   // seat, open below (bearing in from below)
        translate([0, 0, -0.01]) cylinder(d1 = brg_seat_d + 1.6, d2 = brg_seat_d, h = 0.81); // lead-in
        translate([0, 0, SEAT_LO + 7]) cylinder(d1 = brg_seat_d, d2 = 18, h = (brg_seat_d - 18) / 2 + 0.01);
        cylinder(d = 18, h = HOUSE_H + 1);                                     // through bore
        translate([0, 0, SEAT_HI]) cylinder(d = brg_seat_d, h = 7.1);
        translate([0, 0, HOUSE_H - 0.8]) cylinder(d1 = brg_seat_d, d2 = brg_seat_d + 1.6, h = 0.81); // lead-in
        // ---- motor: pilot + slotted M3 (belt tension +-2 along x)
        translate([MX, 0, DECK_Z - 1]) cylinder(d = pilot_d, h = DECK_T + 2);
        translate([MX, 0, DECK_Z + DECK_T - 0.6]) cylinder(d1 = pilot_d, d2 = pilot_d + 1.2, h = 0.61);
        for (x = [-15.5, 15.5], y = [-15.5, 15.5])
            hull() for (dx = [-2, 2])
                translate([MX + x + dx, y, DECK_Z - 1]) cylinder(d = m3, h = DECK_T + 2);
        // ---- window in the base: the motor goes in from below, pilot up into the deck
        translate([-68, -22, -1]) cube([44, 44, BASE_T + 2]);
        // ---- Uno: M3 self-tap holes in the standoffs
        for (h = UNO_HOLES) translate([UNO_X + h[0], UNO_Y + h[1], 2]) cylinder(d = 2.9, h = 10);
        // ---- cover: 2 x M3 self-tap at the +x end of the tray
        for (y = COVER_TABS_Y) translate([5, y, 1]) cylinder(d = 2.9, h = 5);
        // ---- motor cable slot through the +y wall, toward the tray
        translate([-56, 21, 8]) cube([20, 8, 10]);
        // ---- M4 holes: corners + sensor post at (8,-31)
        for (p = [[-70, -34], [34, -34], [34, 34], [-71, 95], [2, 95], [8, -31]])
            translate([p[0], p[1], 0]) chole(m4, -1, BASE_T);
        // ---- pad: 2 x M5 (x = 26, 36), counterbored from below for cap heads
        for (x = [26, 36]) translate([x, 0, 0]) {
            chole(m5, -1, 8);
            translate([0, 0, -1]) cylinder(d = 9.5, h = 5.01);
        }
        // ---- cable slot in the end wall
        translate([-77, -6, 8]) cube([8, 12, 10]);
    }
}
// Motor fits from below through the base window: pilot boss up into the deck,
// M3 x 8 screws from above through the slots (slide to tension the belt).
// The collar's and the 80T hub's 1 mm bosses (d11.5) bear on the inner races only.

// ================= platter (part 8) =================
// d90 x 5 with an integral d20 x 12 clamp hub on the 8 mm shaft (replaces the
// flange coupler). The shaft's top end bears on the platter underside, which sets
// the height; one M3 set screw on a captive nut clamps it. The spindle is a
// separate printed pin pressed into the top face.
// PRINT NOTES: top face (record seat) on the bed, hub up. Flat record seat, no supports.
module platter() {
    difference() {
        union() {
            ccyl(90, 5, cb = 0.8, ct = EF);                                   // ct = bed side when flipped
            translate([0, 0, -12]) clamp_hub(20, 12.01, shaft_fit, boss = false);
        }
        translate([0, 0, 1]) cylinder(d = pin_fit, h = 4.1);                  // spindle pin socket, 4 deep
        translate([31 - 0.1, -1.1, -1]) cube([8.2, 2.2, 4]);                 // flag slot, 3 deep
    }
}

// ================= spindle pin (part 8b) =================
// d7.1 x 9 record spindle with a d5 tail pressed 4 mm into the platter.
// PRINT NOTES: upright, tail down.
module spindle() {
    cylinder(d = pin_fit + 0.15, h = 4);
    translate([0, 0, 4]) cylinder(d = spindle_d, h = 9);
    translate([0, 0, 13 - 0.001]) cylinder(d1 = spindle_d, d2 = spindle_d - 2, h = 1.5);
}

// ================= clamp hub (used by collar, platter, pulleys) =================
// Cylinder od x h on a bore, one radial M3 set screw at height sz (along +x), M3 nut
// in a slot open at the bottom face (z = 0). Optional 1 mm boss d11.5 under the
// bottom face that touches only a 608 inner race (it replaces a shim ring).
module hub_cuts(od, h, bore, sz, slot_r0) {
    translate([0, 0, -2]) cylinder(d = bore, h = h + 4);
    translate([0, 0, sz]) rotate([0, 90, 0]) cylinder(d = 3.4, h = od);         // M3 set screw
    translate([slot_r0, -2.95, -2]) cube([2.7, 5.9, sz + 2 + 3.15]);              // M3 nut slot
}
module clamp_hub(od, h, bore, boss = false, slot_r0 = 5.9, sz = -1) {
    z = sz < 0 ? h / 2 : sz;
    difference() {
        union() {
            ccyl(od, h, cb = EF, ct = EF);
            if (boss) translate([0, 0, -1]) cylinder(d = 11.5, h = 1.01);
        }
        hub_cuts(od, h, bore, z, slot_r0);
    }
}

// ================= shaft collar (part 4) =================
// Under the bottom bearing (body z 0..7, boss 7..8 on the inner race). Push the
// shaft up so the platter seats on its end and the 80T boss on the top inner race,
// then tighten the set screw. The nut slot opens on the boss face.
// PRINT NOTES: as modelled, boss up; drop the nut in from above.
module collar() {
    translate([0, 0, 7]) mirror([0, 0, 1]) clamp_hub(20, 7, shaft_fit, boss = true);
}

// ================= GT2 pulleys (parts 6, 11) =================
// Printed GT2 (2 mm pitch) pulleys. Pitch d = n*2/pi, OD = PD - 0.508.
// The groove is a U shape sized to the 2GT belt tooth (h 0.75); tune gt2_r
// if the belt rides high or binds. If a printed 20T turns out too rough, a
// MISUMI 2GT 20T (bore 5) drops in with the same geometry.
gt2_r = 0.6;                                   // groove radius
function gt2_od(n) = n * 2 / PI - 0.508;
module gt2_teeth(n, h) {
    r = gt2_od(n) / 2;
    linear_extrude(h) difference() {
        circle(r = r, $fn = n * 8);
        for (i = [0 : n - 1]) rotate(i * 360 / n)
            hull() {
                translate([r - 0.75 + gt2_r, 0]) circle(r = gt2_r, $fn = 24);
                translate([r + 0.3, -0.7]) square([0.5, 1.4]);
            }
    }
}
// Modelled in assembly orientation: hub at the bottom (z = 0), belt band z 6..12
// above the hub's bottom face for the 80T, 8..14 for the 20T.
// PRINT NOTES: flip, top flange on the bed. The lower flange is a 45 deg cone, so
// nothing overhangs; the hub's nut slot opens upward.
module gt2_pulley(n, hub_d, hub_h, bore, boss, slot_r0, sz) {
    r  = gt2_od(n) / 2;
    rf = max(r + 1.6, hub_d / 2);
    difference() {
        union() {
            ccyl(hub_d, hub_h + 0.01, cb = EF, ct = 0.01);
            if (boss) translate([0, 0, -1]) cylinder(d = 11.5, h = 1.01);
            translate([0, 0, hub_h]) cylinder(r1 = rf, r2 = r + 0.2, h = rf - r);     // lower flange, ~45 deg
            translate([0, 0, hub_h + (rf - r) - 0.01]) gt2_teeth(n, 6.02);
            translate([0, 0, hub_h + (rf - r) + 6]) ccyl(2 * rf, 1, cb = 0.01, ct = 0.4);  // top flange (bed)
        }
        hub_cuts(hub_d, 20, bore, sz, slot_r0);
    }
}
module pulley80() { gt2_pulley(80, 20, 4.4, shaft_fit, true, 5.9, 3.0); }  // z 51..64 abs (boss 50..51)
module pulley20() { gt2_pulley(20, 16, 6.1, motor_fit, false, 3.5, 3.05); } // z 49..64 abs

// ================= foot (part 13) =================
// TPU (PETG works too). Pin presses into the base's corner M4 holes.
// PRINT NOTES: pin up.
module foot() {
    ccyl(14, 8, cb = EF, ct = 0.8);
    translate([0, 0, 8 - 0.01]) cylinder(d = 4.7, h = 3.5);
}

// ================= home flag (part 8a) =================
// PRINT NOTES: lying flat. Press (or glue) 3 mm into the platter slot; 8 mm hangs
// down through the endstop's slot.
module flag() {
    cube([8, 2, 11]);
}

// ================= clamp (part 9) =================
// d80 puck: sandwiches the label area against the platter. Fill the pocket with
// M8 nuts or coins (~100 g).
// PRINT NOTES: rim face on the bed. The 0.4 mm relief bridges 30 mm (2 layers).
module clamp() {
    difference() {
        ccyl(80, 12, cb = EF, ct = 1.2);
        translate([0, 0, -1]) cylinder(d = 7.6, h = 9);                      // over the spindle
        translate([0, 0, -0.01]) cylinder(d1 = 9.2, d2 = 7.6, h = 0.8);      // entry chamfer
        translate([0, 0, 4]) cylinder(d = 64, h = 10);                        // weight pocket
        translate([0, 0, 12 - 0.8]) cylinder(d1 = 64, d2 = 65.6, h = 0.81);   // pocket rim chamfer
        translate([0, 0, -1]) cylinder(d = 30, h = 1.4);                      // relief: contact on the rim ring
    }
}

// ================= home sensor post (part 14, optional) =================
// Screws to the base hole at (8,-31) on the -y side. Top pad z 56..60 (from chassis
// underside) takes a slotted optical endstop (adapt holes to your module); place
// its slot at (8,-34), i.e. r = 35, under the flag.
// PRINT NOTES: upright. The pad is carried by a printed gusset, no supports.
module sensor_post() {
    difference() {
        union() {
            rbox([-6, -6, 0], [12, 12, 52], r = 2, cb = EF, ct = 0.01);
            hull() {
                translate([-6, -6, 40]) cube([12, 12, 0.01]);
                translate([-6, -12, 52]) cube([18, 24, 0.01]);
            }
            rbox([-6, -12, 52], [18, 24, 4], r = 2, cb = 0.01, ct = 0.6);
        }
        translate([0, 0, -1]) cylinder(d = 3.6, h = 20);                      // M4 thread-formed
        for (y = [-9.5, 9.5]) translate([7, y, 50]) cylinder(d = 2.9, h = 8);  // M3 self-tap
    }
}

// ================= support skid arm (part 15, optional) =================
// Bolts on the chassis pad (top face z = 8) with 2 x M5 from below, reaches r = 120.
// An M4 screw with a PTFE tip (or felt) in the end column, set just touching the
// record underside (z = 83), holds the overhang steady under the lens.
// PRINT NOTES: arm flat on the bed as modelled.
skid_r = 120;
module skid_arm() {
    difference() {
        union() {
            rbox([20, -8, 0], [skid_r - 20, 16, 8], r = 3, cb = EF, ct = 0.8);
            translate([skid_r, 0, 0]) ccyl(14, 67, cb = EF, ct = 0.8);       // column, top z 75 abs
            hull() {                                                          // gusset
                translate([skid_r - 40, -4, 0]) cube([1, 8, 8]);
                translate([skid_r - 7, -4, 0]) cube([1, 8, 50]);
            }
        }
        for (x = [26, 36]) translate([x, 0, 0]) chole(m5, -1, 8);          // M5, nuts on top
        translate([skid_r, 0, 37]) chole(3.6, 0, 30);                        // M4 thread-formed
    }
}


// ================= electronics cover (part 16) =================
// Shell over the Uno + shield + drivers: solid top (heat shield for the record),
// vent slots on the +y side, open at the -x end for USB, DC jack and the supply
// terminal. Two tabs at the +x end take M3 x 8 self-tapping into the tray.
// PRINT NOTES: top face down on the bed. Tabs carry 45 deg gussets.
CV = [-72, 31, 4];  CS = [74, 61, 54];   // min corner, size (top at z 58)
module cover() {
    difference() {
        union() {
            rbox(CV, CS, r = 4, cb = 0.01, ct = CT);
            for (y = COVER_TABS_Y) {
                translate([CV[0] + CS[0] - 1, y - 5, CV[2]]) cube([9, 10, 3]);
                hull() {
                    translate([CV[0] + CS[0] - 1, y - 5, CV[2]]) cube([0.01, 10, 11]);
                    translate([CV[0] + CS[0] - 1, y - 5, CV[2]]) cube([9, 10, 3]);
                }
            }
        }
        // hollow, 2 mm walls and top
        translate([CV[0] - 1, CV[1] + 2, CV[2] - 1]) cube([CS[0] - 1, CS[1] - 4, CS[2] - 1]);
        // vent slots on the +y side
        for (x = [CV[0] + 10 : 8 : CV[0] + CS[0] - 14])
            hull() for (z = [CV[2] + 12, CV[2] + CS[2] - 14])
                translate([x, CV[1] + CS[1] - 3, z]) rotate([-90, 0, 0]) cylinder(d = 3.5, h = 4);
        // tab screw holes
        for (y = COVER_TABS_Y) translate([5, y, 0]) cylinder(d = 3.4, h = 20);
    }
}

if (part == "chassis")     chassis();
if (part == "platter")     translate([0, 0, 5]) rotate([180, 0, 0]) platter();
if (part == "spindle")     spindle();
if (part == "collar")      collar();
if (part == "pulley80")    translate([0, 0, 13]) rotate([180, 0, 0]) pulley80();
if (part == "pulley20")    translate([0, 0, 6.1 + (max(gt2_od(20) / 2 + 1.6, 8) - gt2_od(20) / 2) + 7]) rotate([180, 0, 0]) pulley20();
if (part == "foot")        foot();
if (part == "flag")        rotate([90, 0, 0]) flag();
if (part == "clamp")       clamp();
if (part == "sensor_post") sensor_post();
if (part == "skid_arm")    skid_arm();
if (part == "cover")       translate([0, 0, 62]) rotate([180, 0, 0]) cover();
if (part == "all") {
    chassis();
    translate([0, 0, PLAT_Z]) platter();
    translate([0, 0, PLAT_Z + 1]) spindle();
    collar();
    translate([0, 0, 51]) pulley80();
    translate([MX, 0, 49]) pulley20();
    for (p = [[-70, -34], [34, -34], [34, 34], [-71, 95], [2, 95]]) translate([p[0], p[1], -8]) foot();
    translate([31, -1, PLAT_Z - 8]) flag();
    translate([0, 0, PLAT_Z + 5 + 1.6]) clamp();
    translate([8, -31, BASE_T]) sensor_post();
    translate([0, 0, 8]) skid_arm();
    %cover();
}
