# Reading a record from microscope images

Science Tokyo, Cyber-Physical Innovation 2026. Final presentation about 12/18.

A record is filmed under a microscope while it turns, and the music is
recovered from the pictures alone: an inverse problem from groove images
to sound. See `docs/PRESENTATION_groove_image_to_music.md` for the story
and `docs/METHOD_groove_image_to_music.md` for the method.

## Layout

```
code/                 the method (MATLAB, no toolboxes; see code/README.md)
  +groove/            image -> groove edges -> music
  +rig/               serial driver for the motorised turntable
  examples/           scripts to run: process a video, scan with the rig, draw figures
  tests/              end-to-end test on a simulated disc
data/
  keyence_recording/  the microscope videos (not in git)
docs/                 method, presentation walkthrough, project notes, literature
  archive/            documents of earlier approaches
hardware/turntable/   the stepper turntable: CAD, drawings, firmware, build guide
results/
  figures/            figures for the slides
  runs/<video name>/  what a run writes: edges.mat (cache), result.mat, audio.wav (not in git)
archive/              earlier implementations and the original proposal, kept for reference
```

## Running

From this folder, in MATLAB:

    addpath code/examples
    process_freehand_video          % the 30x recording -> results/runs/20261029_163032/
    process_freehand_video_50x      % the 50x recording -> results/runs/20261027_184833/
    visualize_steps                 % figures of every step -> results/figures/
    visualize_forward_model         % the forward process in one figure

## Conventions

- Lengths in micrometres unless the name says otherwise; settings live in
  `groove.defaultConfig`, each with a comment.
- A run's outputs go in `results/runs/<video name>/`; figures in `results/figures/`.
- Work on a branch and merge to `main` through a pull request.
