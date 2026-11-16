# Recovering audio from microscope video of a record: method

The task splits into two parts that don't share assumptions:

- **Part A, the disc.** Where the spiral is in every frame of the video: its position, its pose, and its spacing.
- **Part B, the music.** Taking Part A as given, read the groove's deviation from the blank spiral, in music time.

Lengths are in µm and image positions in px. p is the pixel size (VHX: 148.8/mag µm), and T = 60/rpm is the time for one revolution.

**All priors and settings live in `code/settings.json`** (record, microscope, rig, video, spiral fit, groove reading, physical limits, music, output). Read it with `S = jsondecode(fileread(fullfile(project_root(), 'code', 'settings.json')))`. Every number below that is a choice rather than a law refers to it; see the Settings section at the end.

---

## Part A: the disc model

### A1. What a spiral is
In disc coordinates, polar about the spiral's centre, with radius r and angle φ, the blank groove is the set of points where

  **Ψ(r, φ) = N(r) + φ/2π is an integer**

- **N(r)** counts grooves inward from some reference radius: N(r) = ∫_r^{r₀} dr′ / P(r′).
- **P(r) is the groove spacing (pitch).** It is the only unknown shape of the spiral. It is smooth and positive. The mastering lathe varies it slowly, over many turns, never within a turn. Model it as a smooth function of r, e.g. a spline with knots every few turns, or a low-order polynomial over the visible band.
- **Ψ is the spiral phase,** measured in turns. Its integer part is which turn; its fractional part is where across the groove spacing. Every blank groove is one level set of Ψ. Music time along the groove is **t = T · Ψ**, up to a constant and a sign.

There is no turn assignment to get wrong: a point's turn is just the integer part of Ψ.

### A2. How the disc sits in each frame

Frame k maps image pixel (u, v) to disc coordinates through its own pose:

  disc point = Rot(-theta_k) * (p*(u, v) + distortion(u, v) - p*c_k)

- **c_k** (2 numbers): the spiral centre's position in the image, px.
- **theta_k** (1 number): the disc's rotation.
- **Global:** P(r) and the distortion field, as before.

Every frame has its own pose. No rig model is built in: hand-turned,
fixed-axis and r-theta stage are all special cases. A rig may enter only as a
prior with an uncertainty (e.g. stage encoder readings), never as a constraint.
For a fixed-axis rig the fitted c_k should come out on a circle; that is a
check (A6), not an assumption.

### A3. What links the frames

1. **Motion links** (frame k-1 -> k): registration of consecutive frames
   gives the content shift along the groove (du), across it (dv) and, if
   needed, a small in-plane rotation. du -> change of theta; dv -> change of
   the radial position, in grooves: dPsi = dv / spacing. Each with its
   uncertainty from the match quality. **dv is the only measurement of how
   many grooves the view crossed.**
2. **Groove phase** (each frame): from the frame's own grooves, the position
   within a groove. Precise (~um) but blind to whole grooves.
3. **Overlaps**: any two frames that see the same patch of disc (one
   revolution apart, or on adjacent radial passes). Registration of the pair
   gives their relative shift; the poses must map that patch to the same disc
   point. Candidates: frames whose predicted disc areas overlap; accepted
   above overlap.minMatch (was rig.loopClosureMinMatch).
4. **Rig prior** (optional): stage encoder (r, theta) per frame.

### A4. Turn identity: phase-locked chaining

Frames are taken in order. For frame k the motion link predicts the
change of Psi from frame k-1 (whole grooves and fraction). The frame's own
grooves give the fraction exactly; the whole-groove count is the one nearest
the prediction. So:

- each frame is re-locked to its own grooves, and errors of the motion links
  do not accumulate;
- a step is safe while the link's across-groove error is under 1/2 groove
  minus the groove-phase error. The **lock margin** of every step is logged;
  steps below spiralFit.lockMarginMin_turns are flagged.

Overlaps then check the counts: between overlapping frames the chain's turn
difference must agree with the overlap. A mismatch says a slip happened
between them; it is located by the smallest margins in that stretch and
reported. The run stops rather than guess.

Within a frame, turns are counted on the grooves themselves: a groove is a
dark track spanning most of the frame (dust and specks on lands are not), and
tracks are numbered in order. Only grooves that exist get numbers, also where
the pitch changes within a turn (between tracks).

### A5. Fit

Unknowns: c_k and theta_k for every frame; P(r) and the distortion.

Data, all as robust (Huber) least squares with their measured uncertainties:
- groove readings, with turn numbers fixed by A4: residual Psi - n (not
  wrapped, so the fit cannot slip a turn);
- motion links (consecutive frames) and overlaps (pairs);
- rig prior, if any.

The system is sparse: each frame couples only to its neighbours and its
overlaps. Start from the chain of A4. Stages: poses with P fixed; then
P(r); then the distortion. Poses from all frames at reduced resolution; the
frames used in Part B also at full resolution.

P(r) stays a smooth function of r (knot every record.pitchKnotTurns turns)
over the whole radius range covered. Pitch changes within a turn (between
tracks) are not in P(r); they show as a slow offset on those grooves, which
Part B handles (turn counting; the groove's own trend as reference where the
model is off by more than 1/4 turn).

### A6. Checks

- **Lock margin:** smallest per-step margin over the video; flagged steps.
- **Overlaps:** turn differences that disagree with the chain (must be 0);
  radial and along-groove residual, um.
- **Motion-link residuals** after the fit: do the poses agree with the
  measured motion?
- **Phase residual:** about the music's rms, not larger.
- **Spiral centre path c_k:** plotted. For a fixed-axis rig it should be a
  circle plus the rig's shake; for an r-theta stage it should follow the
  stage.
- **P(r):** smooth, no jumps.

---

## Part B: music on the spiral

Part A is taken as given. Each groove reading in each frame now has a known Ψ.

### B1. Pick frames
With poses known, pick frames covering one revolution at k views per point (about W/k px apart), preferring the best focus. k = 4 gives up to about 6 dB less noise than 1–2 views.

### B2. Read across the groove, along the spiral normal
- Resample each frame along the **spiral's** local normal, i.e. the gradient of Ψ, which is not quite radial. Each column then crosses the groove at right angles.
- Fit the groove profile per column (robust Gauss–Newton):
  L − (L − D)[Φ((y − c + w/2)/s) − Φ((y − c − w/2)/s)] + b·exp(−(y − c)²/2τ²)
  This gives the centre c and width w; L, D vary slowly; s and b are shared.
- Reject impossible readings:
  - the model doesn't fit;
  - the width is implausible;
  - a wall moves sideways faster than about 0.3 m/s at groove speed 2πr/T;
  - a wall bends tighter than about 10 µm radius.
  All limits carry a 3σ noise allowance. Drop rejected readings; don't smooth over them.

### B3. Music time and displacement
For each accepted reading:
- **Time:** t = T · Ψ_blank, the Ψ of the blank groove it belongs to, i.e. round(Ψ) plus the angle part.
- **Displacement:** x = (Ψ − round(Ψ)) · P, the centre's offset from the blank spiral (µm, sign: outward +). Width w as read.

Every frame's readings go straight to music time; nothing is chained or paired. Overlapping frames give several readings of the same t. Their agreement is the check that Part A got the integer offsets right. Disagreement by a whole turn's worth of music means a slipped turn: go back to A4.

### B4. Time bins
- A bin is a fixed slice of Ψ, so the same at every radius: ΔΨ = 1/(T·f_bin). f_bin is `music.binRate_Hz` (default 32 kHz for a 15 kHz audio band, `music.bandHigh_Hz`). It must be at least 2 × bandHigh; a lower rate means more pixels and less noise per bin.
- Average all readings in each bin (robust mean), and count the views.
- Bin width in px is ΔΨ · 2πr / p, and must stay at or above 1:

  | | 32 kHz, r = 130 mm | 32 kHz, r = 60 mm | 48 kHz, r = 60 mm |
  |---|---|---|---|
  | 50× | 4.8 px/bin | 2.2 px/bin | 1.5 px/bin |
  | 30× | 2.9 px/bin | 1.3 px/bin | **0.9 px/bin** (undersampled) |

- Gaps: interpolate if short, silence if long; report the share.

### B5. Sound
- Velocity = dx/dt, then RIAA playback, then a band-pass `music.bandLow_Hz`–`music.bandHigh_Hz` (default 20 Hz – 15 kHz), then resample to `output.fsOut_Hz` for the WAV.
- Mono = centre, L = inner wall, R = outer wall (centre ∓ w/2).
- Write the raw WAV plus a listenable one: high-pass at 50 Hz, level set by the 99.5th percentile with a tanh soft limit. Never normalise to the peak.
- Save everything (`-v7`) and a log.

### B6. Checks
- Views per bin: median, minimum; % of bins empty.
- Spread between views of the same bin, in µm: the measurement noise, and the basis for error bars.
- Jumps: none. A step of about one groove's worth means Part A is wrong.

---

## Why the first implementation failed (keep for the report)

The first version mixed models:
- It unwarped images onto **rings** about the rig axis.
- It forced silent grooves flat, which hid the spiral's slope inside a "skew".
- It followed grooves frame to frame by **pairing lanes.** Pose errors of a few px are a large fraction of the 24 px groove spacing at 30×, so pairings slipped.
- It only knew it was a spiral at the ring wrap, as "+1 lane".
- A spiral fit then tried to assign turns by nearest radius after the fact, with a sign error in the radial pose.

The result was music jumping by whole turns.

The fix is the split above. The spiral phase Ψ carries the turn number everywhere, so nothing needs pairing or assigning. The music is read only after the disc model is settled.

---

The second implementation kept the fixed-axis rig model of the earlier A3. It made the radial
position of each frame a smooth curve over 30 frames, which is what prevented
whole-groove slips. When the hand-turned disc shook across the grooves by
0.3-0.4 groove per frame (30x, frames 544-553), the groove phase alone became
ambiguous, while the measured motion across the grooves (dv), which agreed
with it to 0.03 groove, was not used.

The fix is A2-A4 as they now stand: every frame has its own pose, the motion across the grooves decides the whole grooves between frames, each frame's grooves give the fraction, and overlaps check the count.

---

## Settings (`code/settings.json`)

Units are in the field names.

- **record:** What we assume about the disc. pitch_um is only the starting value: the pitch P(r) is solved for in Part A, within pitchMin_um..pitchMax_um, as a smooth curve with a knot every pitchKnotTurns turns.
- **microscope:** Pixel size on the record = pixelAt1x_um / magnification (Keyence VHX VH-ZST: 15.24 mm field at 20x over 2048 px). Lens distortion is a smooth field sum a_ij x^i y^j over the image with these powers; lower powers of x would be indistinguishable from a groove's own offset and slope. mirrored: true if the VHX shows a mirror image.
- **rig:** Priors on the rig, if any. The poses are free per frame (A2); a rig enters only as a prior with an uncertainty (stage encoder). overlap.minMatch: smallest correlation accepted for two frames seeing the same disc area (must also stand out 5x above unrelated frames).
- **video:** Part A runs on every video frame at 1/downsample resolution. views: how many picked frames should see each point of the groove in Part B (more views = more averaging = less noise; 1.5 GB of frames at 4 views for one 4-min video). focusWeight: 1 = always the sharpest frame in each window, 0 = ignore focus.
- **spiralFit:** Part A phase fit. Readings sit at integer spiral phase; the music is the 'noise' and is handled by a robust (Huber) loss with threshold huberK x the robust spread. Stages run in order. initPhaseErrorMax_turns: if the starting poses are worse than this, the fit stops and says so rather than slipping a turn. subsample: use every n-th groove reading per frame (the music averages out anyway). lockMarginMin_turns: steps of the phase-locked chain (A4) whose margin against the half-groove ambiguity is below this are flagged.
- **grooveReading:** Part B profile fit across each groove, along the spiral normal. window: half-width of the window read across a groove, as a fraction of the pitch. bottomLine: model the thin bright line the rounded groove bottom reflects.
- **physicalLimits:** Readings a cut groove cannot produce are dropped: a wall moving sideways faster than vMax (vs the groove speed 2 pi r / T), or bending tighter than rhoMin. Each limit gets an allowance of noiseSigma x the robust spread of that quantity.
- **music:** Part B. A time bin is a fixed slice of spiral phase (1/binRate_Hz of music), the same at every radius. binRate_Hz must be at least 2 x bandHigh_Hz (Nyquist). A lower bin rate averages more pixels per bin (less noise) and keeps inner grooves at low zoom sampled (bin width in px = 2 pi r / (binRate T p) should stay >= 1). Gaps up to gapFillMax_ms are interpolated; longer ones play as silence.
- **output:** WAVs are written at fsOut_Hz (resampled from the bin rate). The listenable version (_eq.wav) is high-passed and levelled by a percentile of the signal with a tanh soft limit, never normalised to the peak (a few spikes would make everything inaudibly quiet).
