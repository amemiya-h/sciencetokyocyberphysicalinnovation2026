# Smart Irrigation: Soil Moisture Estimation from Sparse Sensors

Science Tokyo, Cyber-Physical Innovation 2026. Interim presentation ~11/9, final ~12/18.

We estimate the hidden soil moisture distribution from a few moisture sensors and an inverse model, and study whether designed irrigation pulses make the soil easier to identify, and at what water cost.

## Layout

```
docs/
  science.md       Problem, method, novelty, findings     → scientific report
  project.md       Team, workflow, decisions, timeline    → project report
  meetings.md      Meeting notes, newest at the bottom    → project report
  experiments.md   One entry per experiment (E001, ...)   → results in both
  references.bib
  archive/         Original proposal and candidate idea lists
code/              MATLAB functions
  experiments/     One script per experiment: E001_forward_sanity.m, ...
results/figures/   Figures, named E###_name.png
startup.m          Adds code/ to the MATLAB path
```

Each experiment's ID (E001, ...) is shared by its script, its entry in `experiments.md`, and its figures, so every result traces back to the code that produced it.

## Conventions

- Run `startup` first (automatic if MATLAB starts in this folder).
- Model logic lives in functions in `code/`; experiment scripts only set up, call functions and plot.
- Units: cm and h (proposed). Put units in each function's header comment.
- Experiment scripts call `rng(seed)` at the top and save figures with `save_figure(fig, 'E003', 'name')`.
- Work on a branch and merge to `main` through a pull request.
