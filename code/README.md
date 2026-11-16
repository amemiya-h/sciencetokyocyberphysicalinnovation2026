# vinylscan

Version 1.0, locked 2026-11-15. Method: `docs/METHOD_groove_image_to_music.md`.

Recovers stereo audio and groove position from microscope video of a record
turning slowly on a stepper-driven turntable.

Written for MATLAB (R2020b or newer, no toolboxes). Also runs in GNU Octave,
except for reading video files.

## The idea

The microscope stays at one radius while the disc turns. From every frame
only a narrow slice across the grooves is used, so the camera behaves like a
line scanner and the spiral comes out already unwound: disc angle along one
axis, radius along the other. No image stitching, no motion tracking.

In that unwound view each groove is a dark band between two edges.

- The edge nearer the spindle is the left channel, the edge nearer the rim
  is the right channel.
- The slow drift of the band is the groove position: the spiral, the
  mastering pitch changes and any off-centre wobble.

One revolution captures every groove in the field of view. Bands are laid
end to end to give a continuous groove, the microscope is stepped inward,
and overlapping rings are spliced by matching the groove wiggle.

## Quick start

    addpath examples
    demo_synthetic          % simulated disc, no hardware needed

    run tests/test_synthetic   % end-to-end check against known truth

For real scans copy `examples/process_real_side.m` and edit the marked lines.

## Two ways in

| Scan | Entry point | Needs |
|---|---|---|
| Stepper turntable, known frames per revolution | `groove.processRing` / `groove.processSide` | accurate `framesPerRev` |
| Turned by hand, or motor not synchronised with the camera | `groove.processFreehand` | consecutive frames overlapping by half a frame or more |

`processFreehand` places the frames itself, by matching the groove wiggles
they share, averages every view of each groove, and finds the revolution
from the music repeating one groove over. It also reports signal against
noise by frequency band, measured from odd frames against even frames.
See `examples/process_freehand_video.m`.

Speed: reading the groove edges is the slow step. It runs on all parallel
workers (`cfg.run.parallel`), and `cfg.run.edgeCache` keeps the result in a
`.mat` file so a rerun starts at registration. `report.timing` lists the
seconds per stage; `examples/profile_freehand_video.m` runs the MATLAB
profiler on a short stretch.

Slow groove position from a
hand-turned scan is only approximate; the audio does not depend on it.

## Motorised rig

`+rig` drives the stepper turntable in `hardware/turntable` (Arduino Uno,
CNC shield, firmware `tt_firmware`) over its serial protocol.

| Script | Rig |
|---|---|
| `examples/scan_ring_motorized.m` | turntable only: one ring |
| `examples/scan_side_motorized.m` | turntable and radial axis: step and repeat over several rings |

Both turn the disc at a steady speed while the microscope records, and
then read the video with `processFreehand`, so the camera needs no link
to the motor. Recording is started and stopped by hand. Set `port = ""`
for a dry run against `rig.simulated()`, which prints every command.

## What to film

For each radial position, one video of a little more than one revolution
(about 1.05 turns).

- **Orientation.** Grooves must run horizontally in the image.
- **Speed.** The disc may move at most one frame width between frames.
  Much less is better: aim for 0.1 to 0.3 mm of travel per frame.
- **Exposure.** Short enough that the surface moves under about 2 um
  during it.
- **Timing.** `cfg.turntable.framesPerRev` must be accurate, since it is
  the only link between frames and disc angle. Triggering the camera from
  the stepper pulses makes it exact.
- **Overlap.** Step the microscope by less than the field of view, so
  neighbouring rings share at least two or three groove turns.
- **Radius.** Give the radius at the image centre for each ring. Relative
  accuracy between rings should be within about one groove pitch (0.1 mm);
  if it is not, set `cfg.join.searchTurns = Inf`.
- **Format.** Lossless or lightly compressed video, or numbered images.

Before a full run, look at `groove.scan.buildKymograph`: every groove
should be a clean dark band with sharp edges.

## Layout

    +groove/
      defaultConfig.m        every tunable parameter, documented
      processRing.m          one video        -> unwound groove edges
      processSide.m          several videos   -> one continuous groove
      processFreehand.m      hand-turned video -> unwound groove edges
      +io/                   video and image-folder readers, CSV writer
      +scan/                 frames -> groove edges at every sample
      +track/                follow grooves, unwind, join rings, position
      +mosaic/               scans without known angles: register, average, unwind
      +audio/                edges -> stereo audio (RIAA), filters, click removal
      +sim/                  synthetic disc renderer for testing
      +util/                 gap filling, correlation search
    +rig/                    serial driver for the motorised turntable and radial axis
    +groove/+viz/            one worked example of every step, for figures
    examples/                demo, templates for real data, motorised scan scripts,
                             visualize_steps.m and visualize_forward_model.m (figures for slides)
    tests/                   end-to-end test on the simulator

The pipeline, in call order:

| Step | Function | Result |
|---|---|---|
| 1 | `groove.scan.extractEdges` | both edges of every groove at every sample |
| 2 | `groove.track.linkTracks` | each groove band followed along the scan |
| 3 | `groove.track.unwindRing` | bands laid end to end in playback order |
| 4 | `groove.track.joinRings` | rings spliced into one groove |
| 5 | `groove.audio.edgesToAudio` | stereo audio |
| 6 | `groove.track.groovePosition` | groove radius and width against angle |

Each function's help text (`help groove.track.unwindRing`) explains its
reasoning.

## Outputs

- **Audio**: left and right, RIAA de-emphasised, normalised.
- **Groove position**: radius of the groove centre about the turntable
  axis and groove width, both against unwound angle and playback time.
  `groove.track.removeEccentricity` fits and removes the off-centre wobble.

## Tested, and not

- **Simulator** (`tests/test_synthetic.m`, stepper path): edge positions to
  about 0.01 um, crosstalk below -50 dB, ring joins within half a sample.
- **Real video** (freehand path): one hand-turned Keyence recording, 1014
  frames at 4.96 um/pixel. 57 consecutive turns, 102.6 s of audio.
  Everything from `groove.mosaic.fromEdges` onward ran on it.
  `groove.mosaic.frameEdges` was checked on two full frames of it.
- In MATLAB R2024b `processFreehand` runs end to end from the video file,
  with parallel edge reading (about 4 minutes on 8 workers). Two MATLAB
  runs recovered only 34 of the 57 turns because of a groove-numbering
  bug (two grooves given the same number where the groove spacing
  widens). The fix was verified by running the edges MATLAB had cached
  through the library under Octave (57 turns); the MATLAB run with the
  fix is not yet known.
- **Motorised rig:** nothing has touched hardware. The firmware compiles
  and behaves correctly against a simulated Arduino on a PC (not built
  with the Arduino toolchain); the driver was run against
  `rig.simulated()`; the scan scripts were dry-run up to the point where
  they read a video. Joining freehand rings was checked by cutting the
  real 57-turn ring into two overlapping pieces at different sample rates
  and joining them again (same length, 0.16 um rms difference).
- Everything else here ran under GNU Octave. `imageFolderFrameSource` has
  not been run at all.
- The freehand path has no simulator test yet.

## Known limits

- **Channel assignment is first order.** One edge per channel ignores the
  finite cutter geometry. If channels come out swapped, swap the columns;
  for absolute polarity set `cfg.audio.invert`.
- **Half-sample step at ring joins.** Each ring has its own sampling
  phase. Starting every ring at the same stepper position removes it.
- **Click removal is crude.** Edge jumps faster than
  `cfg.audio.maxVelocityCmS` are bridged; smaller clicks remain.
- **Memory.** A whole side at 96 kHz holds about 2 GB of edge data. Use
  48 kHz if that is too much.
- **Touching grooves.** Where loud passages leave no land between grooves
  the detector loses both and interpolates.
