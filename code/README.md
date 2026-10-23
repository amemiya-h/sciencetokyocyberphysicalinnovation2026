# Code

Recovering audio from camera images of a vinyl record's groove.

- **Forward path** (`forward_*.m`): music → groove shape → simulated camera frames, saved to `data/<dataset>/`.
- **Retrieval path** (`retrieve_centreline.m`): frames → groove edges → centreline → audio.

Run `startup` in the repository root first; it adds `code/` and `code/lib/` to the path. All lengths are in micrometres (µm) unless stated. In a frame, rows run along the groove and columns run across it.

## Scripts (`code/`)

| File | What it does |
|---|---|
| `forward_sine.m` | Forward path for a 1 kHz test tone, like a test record; writes `data/sine/`. Takes about a minute; good for checking the retrieval. |
| `forward_music.m` | Forward path for a clip of the Brahms recording (stereo, RIAA); writes `data/music/`. |
| `forward_microscope_view.m` | Renders wide 5× microscope views with many neighbouring turns, as a phone photo through the eyepiece and as an eyepiece camera; writes `data/view_*` and `results/figures/view_*.png`. |
| `retrieve_centreline.m` | Retrieval path for one dataset (set `dataset` at the top): tracks the groove, plays it back, prints coverage / centreline RMSE / SNR, writes WAVs to `results/runs/`, and plots. |
| `run_full_track.m` | End to end on the whole recording: forward path (about 12,500 frames, about 4–5 GB) then retrieval. Can be stopped and restarted. |
| `compare_setups.m` | Runs forward + retrieval for every camera preset × lighting type on a short clip and tabulates image brightness, noise and audio quality. |
| `project_root.m` | Returns the repository root path. |
| `save_figure.m` | Saves a figure as PNG and PDF under `results/figures/`. |

## Library (`code/lib/`)

**Record, groove and cutting**

| File | What it does |
|---|---|
| `default_scene.m` | Record, groove, vinyl and dust parameters: radius, rpm, depth, wall angle, groove spacing, roughness, etc. Values marked "assumed" should be replaced with measurements. |
| `load_clip.m` | Reads a time range of an audio file. |
| `audio_to_groove.m` | Cuts audio into groove motion as a lathe does: RIAA pre-emphasis, velocity → displacement, 45/45 stereo (L+R sideways, L−R vertical). |
| `riaa_response.m` | The RIAA playback curve (its inverse is the cutting curve). |
| `groove_motion_at.m` | Evaluates groove motion at any time from the audio-rate signal (local spline). |
| `groove_surface.m` | Height map of one or more V-grooves, with rounded bottom and edges; also marks the wall regions. |

**Light, optics and camera**

| File | What it does |
|---|---|
| `light_sources.m` | Light directions for `coaxial` (through the lens), `side` or `ring` lighting. |
| `cone_samples.m` | Evenly spread directions inside a cone; used for light sources and the lens aperture. |
| `fresnel_reflectance.m` | Reflectance of the vinyl (PVC) surface vs angle. |
| `reflectance_lut.m` | Lookup table: light reaching the lens vs surface orientation, combining a rough-surface (microfacet) reflection model with Fresnel, diffuse reflection and the V-groove's corner-reflector double bounce. |
| `surface_normals.m` | Surface normals from a height map. |
| `cast_shadow.m` | Shadows from low side lights. |
| `dust_mask.m` | Random dust particles (repeatable per frame). |
| `scene_radiance.m` | Light sent into the lens by every point of the surface. |
| `camera_optics.m` | Lens blur (diffraction + depth-dependent defocus), pixel averaging, lens aberration blur. |
| `camera_sensor.m` | Shot noise, read noise, pixel gain variation, bit depth, optional averaging of several exposures. |
| `camera_preset.m` | Candidate setups: `microscope10x`, `microscope5x`, `phoneEyepiece5x`, `telecentric2x`, `usbMicroscope`, `phoneMacro`. Values are typical guesses, not datasheets. |
| `simulate_scan.m` | **Forward model entry point.** Ties the above together and writes the frames, `meta.mat` and `truth.mat` (see below). Runs frames in parallel with `parfor` and resumes interrupted runs. |
| `eyepiece_look.m` | Turns a frame into a lamp-tinted, circular-field picture like a photo through the eyepiece (display only). |

**Retrieval**

| File | What it does |
|---|---|
| `retrieve_audio.m` | **Retrieval entry point.** Tracks all frames, fills gaps, plays back, then scores against `truth.mat`. |
| `track_groove_dataset.m` | Runs the edge tracker frame by frame, carrying the groove position across frames. |
| `track_groove_edges.m` | Per row: finds edge candidates to sub-pixel accuracy and picks the best left/right pair by edge strength, width and closeness to the previous row. `feature = 'step'` for head-on light, `'ridge'` for thin bright edges under side light. |
| `read_groove_frame.m` | Loads one frame scaled to [0, 1] and its row indices. |
| `fill_gaps.m` | Interpolates rows where no edge pair was found. |
| `centreline_to_audio.m` | Plays the centreline back like a turntable: velocity, RIAA de-emphasis, 20 Hz–20 kHz band-pass, resample to 48 kHz. |

**Plots and evaluation**

| File | What it does |
|---|---|
| `plot_edges.m` | Detected vs true edges over a frame. |
| `plot_edge_profiles.m` | Brightness across the groove at chosen rows, with edges marked. |
| `plot_error_along_groove.m` | Centreline error vs position. |
| `plot_error_histogram.m` | Distribution of the centreline error. |
| `plot_audio.m` | True vs recovered audio: waveform and spectrum. |
| `plot_groove.m` | 3-D and top view of a groove surface patch. |
| `image_stats.m` | Brightness of land, rims and walls, and noise in a frame (used by `compare_setups.m`). |
| `error_metrics.m` | RMSE, MAE, bias etc. of an error vector (currently unused). |
| `plot_intensity_maps.m` | Side-by-side brightness images (currently unused). |

## Data handed from forward to retrieval

Each dataset in `data/<name>/` contains:

- `frame_00001.png`, … — camera frames, 16-bit greyscale, each `frameRows` rows along the groove.
- `meta.mat` — what a real instrument would know: pixel grid `x`, `y`, pixel size `dy`, `scene`, `cam`, `light`, `frameRows`, `nFrames`, `grooveSpeed`, `exposure`.
- `truth.mat` — the true sideways (`xc`) and vertical (`vert`) groove motion per row. Used only for scoring, never for the reconstruction.

These folders can be regenerated with the `forward_*.m` scripts and are excluded by `.gitignore` (`data/*/`).
