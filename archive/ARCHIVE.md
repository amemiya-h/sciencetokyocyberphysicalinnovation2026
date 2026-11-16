# Archived implementations

Kept for reference only. This folder lies outside `code/`, so nothing in it is on the MATLAB path.
The canonical code is `code/+groove` (see `code/README.md`).

| Where | What it was |
|---|---|
| this folder (`retrieve_keyence_ring.m`, `video_to_audio.m`, `lib/`, `forward_*.m`) | First implementation: forward simulator, and retrieval by unwarping frames onto rings. Described in `README.md` here. |
| `spiral_fit/` | Second implementation: `disc_model_fit.m` (Part A) and `music_on_spiral.m` (Part B), with `settings.json`, `lib/` and `experiments/E01`-`E05`. Described in `docs/archive/METHOD_groove_inverse_problem.md`. |

Notes for anyone running the archived code:

- `spiral_fit/project_root.m` finds the repository root from its own
  location. It was written for `code/`, so from here it points two levels
  too deep. Move it back to `code/` or edit it before use.
- The diagnostic scripts in `results/runs/20261027_184833/` (`diag4.m`,
  `diag5.m`) call the `spiral_fit` functions.
- Archived 2026-11-15.
