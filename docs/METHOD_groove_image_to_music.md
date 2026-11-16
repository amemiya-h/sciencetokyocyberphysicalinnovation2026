# From groove images to music: method

Reference for the canonical implementation in `code/+groove` (freehand path,
`groove.processFreehand`). Locked on 2026-11-15. It replaces
`docs/archive/METHOD_groove_inverse_problem.md`, which describes the
archived spiral-fit implementation.

Lengths are in micrometres unless stated. "Row" is the radial direction in
the image, "column" runs along the grooves.

## 1. The problem

**Forward process (what made the data).** Music was cut into a spiral
groove: each wall of the V-shaped groove carries one stereo channel. Seen
from above under head-on light, the flat land between grooves is bright
and the groove is dark, so each groove shows two edges. A microscope films
a small window of the disc while the disc turns.

**Inverse problem.** Given the frames, recover the music.

**What is unknown.**

| Unknown | Kind |
|---|---|
| Position of both edges of every groove | wanted |
| How far the disc turned between frames | nuisance |
| How far the disc slid sideways between frames | nuisance |
| Tilt and curvature of the grooves in the image | nuisance |
| How image shift scales across the frame height | nuisance |
| Length of one revolution in pixels | nuisance |
| Which groove in one frame is which in the next | nuisance |

Nothing about the rig is assumed known except the pixel size and where
the spindle lies in the image. Every nuisance quantity is estimated from
the grooves themselves.

**Why it is hard.**

- The signal is small. Above 1 kHz the edge moves by less than 1 um rms;
  one view of an edge is uncertain by about 0.66 um (30x).
- The last step, displacement to velocity, multiplies each frequency by
  itself. It amplifies exactly the treble that is weakest.
- The data are redundant but unordered: each point of groove appears in
  several frames at unknown offsets.

## 2. The steps

Function names are in `code/+groove/+mosaic` unless a package is given.

### Step 1. Edges in each frame (`frameEdges`)

- The land/groove threshold is half-way between the local bright and dark
  levels, taken over blocks of rows, so uneven lighting does not move it.
- Regions without real contrast count as land (`cfg.detect.minContrast`).
- In every column, each bright-to-dark crossing followed by a
  dark-to-bright crossing is one groove; the crossing is placed to a
  fraction of a pixel by linear interpolation.
- Runs narrower than 30 um or wider than 220 um are rejected.
- Which grooves exist is decided from a band of 21 columns at the image
  centre; each is then followed sideways column by column.

Output per frame: top and bottom edge row of every groove at every column.

### Step 2. Where each frame sits (`registerFrames`, `pairShift`)

- Each groove's centre line, minus a fitted parabola, is its **wiggle**:
  the audio, acting as a fingerprint.
- For consecutive frames, every groove's wiggle is correlated with its
  counterpart, and the correlations of all grooves are summed. The peak is
  the shift along the groove. Quiet grooves borrow certainty from loud ones.
- Grooves further from the spindle move further. That scale against row
  is fitted from all frame pairs (8 % across the frame at 30x) and used in
  a second pass.
- Grooves are matched by position, trying the nearest groove and one
  spacing either side; the fingerprints decide.
- Each groove keeps a number from frame to frame. An unmatched groove is
  numbered from the spacing of its two numbered neighbours.

Output: position of every frame along the groove, in pixels, and a number
for every groove in every frame.

### Step 3. Averaging all views (`buildMosaic`)

- Each numbered groove band gets one row of a long strip, the **mosaic**;
  its columns are positions along the groove, one pixel apart.
- Each frame drops the central part of each groove (1.5 mm either side of
  the image centre, where lens distortion is small) into that strip, with
  a weight that fades toward the edges of the part used.
- Before it is added, the whole frame is slid radially to agree with what
  is already there. That removes hand shake.
- The tilt and curvature shared by all grooves are removed.
- A second pass aligns every frame to the first-pass mosaic and drops
  readings further than 7.5 um from it.
- The mosaic is also built from odd frames only and from even frames
  only, for steps 5 and 7.

### Step 4. Closing the revolution and unwinding (`findRevolution`, `unwindMosaic`)

- The groove is a spiral, so one revolution on, a band shows the music
  its neighbour showed at the start. Each band is correlated with the next
  band at large offsets; the offset where all agree is one revolution.
- Each band then contributes exactly one revolution, and the next band
  takes over: one continuous groove.
- A band with holes is kept and the holes bridged; a band number never
  seen is left out.
- One revolution is 1.8 s at 33 1/3 rpm, which fixes the sample rate. No
  radius or speed measurement is needed.

### Step 5. Rejecting clicks (`rejectDisagreement`, `groove.audio.declick`)

- Where the odd-frame and even-frame mosaics differ by more than 6 times
  the local typical amount, the sample is dropped and bridged.
- Any remaining edge movement faster than 40 cm/s is bridged as well.

### Step 6. Edges to sound (`groove.audio.edgesToAudio`)

- Inner edge is the left channel, outer edge the right; each divided by
  the square root of 2 (the wall is at 45 degrees).
- Displacement is differentiated to velocity, high-passed at 20 Hz, and
  passed through the standard RIAA playback curve.

### Step 7. Noise filter (`splitHalfNoise`, `groove.audio.noiseFilter`)

- Half the sum of the odd and even mosaics is groove plus noise; half
  their difference is noise alone. Their power spectra give signal and
  noise at every frequency.
- Each frequency is multiplied by (total - noise) / total. This is the
  Wiener filter, and has the form of a Tikhonov filter factor.

## 3. Results

| | 30x recording | 50x recording |
|---|---|---|
| File | `20261029_163032.avi` | `20261027_184833.avi` |
| Pixel size | 4.96 um | 2.98 um |
| Frames | 1014 | 2791 |
| Revolutions filmed | 1.09 | 1.40 |
| Grooves per frame | about 58 | about 32 |
| Groove turns in the unwound chain | 57 (102.6 s) | 32 bands, one of them empty |
| Noise per band | about 0.2 um | about 0.06 um |

Signal-to-noise of the averaged result:

| Band | 30x | 50x |
|---|---|---|
| 30-100 Hz | 34 dB | 40 dB |
| 100-300 Hz | 28 dB | 39 dB |
| 300-1000 Hz | 25 dB | 36 dB |
| 1-3 kHz | 13 dB | 21 dB |
| 3-6 kHz | 3 dB | 13 dB |
| 6-10 kHz | noise | 9 dB |
| 10-15 kHz | noise | 3 dB |

The 50x audio had not been heard when this was written: the run that
produced these numbers wrote silence because of a bug fixed afterwards.

The 50x recording differs from the 30x one in three ways at once: pixel
size, number of views per point (about 7 against 5), and contrast (about
twice the range). Their separate contributions have not been measured.

## 4. Validation

- **Independent method.** The loudness envelope of the 30x result
  correlates 0.98 with the output of the archived implementation, which
  shares no code.
- **Listening.** The 30x result is recognisable music with correct stereo.
- **Split halves.** The noise figures above come from the data, not from
  a model.
- **Simulator.** The stepper path reproduces a synthetic disc to 0.01 um
  (`tests/test_synthetic.m`). The freehand path has no simulator test.

## 5. Limits

- One revolution at one radial position. Joining several rings was tested
  only by cutting one real ring in two and rejoining it.
- Slow groove position is approximate for a hand-turned disc.
- Only the central part of each frame is used; the rest is discarded
  because lens distortion is not corrected.
- One edge per channel is a first-order model of the groove geometry.
- Channel separation and frequency response have not been measured
  against a test record.

## 6. Running it

    addpath code/examples           % from the repository root
    process_freehand_video          % 30x recording
    process_freehand_video_50x      % 50x recording
    visualize_steps                 % figures of every step

About 4 minutes for the 30x recording in MATLAB R2024b on 8 workers
(edges 159 s, registration 63 s, mosaic 20 s). All settings are in
`groove.defaultConfig`, each with a comment.
