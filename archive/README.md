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
| `forward_microscope_view.m` | Renders wide microscope views with many neighbouring turns: a phone photo through a 5× eyepiece, a 5× eyepiece camera, and a Keyence VHX at 100×; writes `data/view_*` and `results/figures/view_*.png`. |
| `retrieve_centreline.m` | Retrieval path for one dataset (set `dataset` at the top): tracks the groove, plays it back, prints coverage / centreline RMSE / SNR, writes WAVs to `results/runs/`, and plots. |
| `run_full_track.m` | End to end on the whole recording: forward path (about 12,500 frames, about 4–5 GB) then retrieval. Can be stopped and restarted. |
| `forward_keyence_ring.m` | Forward path for the Keyence rig: renders a full ring of overlapping VHX images of a turning disc (many turns per image, camera skew, off-centre disc, defects fixed to the record); writes `data/keyence_ring/`. |
| `retrieve_keyence_ring.m` | Retrieval for a ring of images (set `dataset` at the top: the simulation, or a folder from `extract_ring_frames.m`; `method` = `'fit'` or `'edges'`): finds every groove (fitted profile or both edges), lines the images up, follows each groove round and round the spiral, corrects the off-centre disc, writes stereo + mono WAVs to `results/runs/`, and scores against `truth.mat` if present. |
| `video_to_audio.m` | **One step from a VHX video to audio:** `video_to_audio('data/keyence_recording/<file>.avi')` (or no argument to pick the file). Extracts one revolution of frames, reads the grooves, writes `results/runs/<name>_polar_all_eq.wav` (listen to this) plus the raw audio, every chain, a log and a `.mat`. Options: `'magnification'` (default 50), `'rpm'`, `'mirrored'`, `'redo'`, and `'views'` (e.g. 4: every point seen in about 4 frames, averaged into less noise; results tagged `<name>_v4`). |
| `compare_setups.m` | Runs forward + retrieval for every camera preset × lighting type on a short clip and tabulates image brightness, noise and audio quality. |
| `project_root.m` | Returns the repository root path. |
| `save_figure.m` | Saves a figure as PNG and PDF under `results/figures/`. |

## Library (`code/lib/`)

**Record, groove and cutting**

| File | What it does |
|---|---|
| `default_scene.m` | Record, groove, vinyl and dust parameters: radius, rpm, depth, wall angle, groove spacing, roughness, etc. Groove width and spacing are matched to Keyence VHX measurements of a real LP; values marked "assumed" are still guesses. |
| `load_clip.m` | Reads a time range of an audio file. |
| `audio_to_groove.m` | Cuts audio into groove motion as a lathe does: RIAA pre-emphasis, velocity → displacement, 45/45 stereo (L+R sideways, L−R vertical). |
| `riaa_response.m` | The RIAA playback curve (its inverse is the cutting curve). |
| `groove_motion_at.m` | Evaluates groove motion at any time from the audio-rate signal (local spline). |
| `envelope_max.m` | Running maximum of a signal's magnitude; gives each turn's swing for variable groove spacing. |
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
| `camera_preset.m` | Candidate setups: `keyenceVHX` (with zoom, matched to real images), `microscope10x`, `microscope5x`, `phoneEyepiece5x`, `telecentric2x`, `usbMicroscope`, `phoneMacro`. Apart from `keyenceVHX`, values are typical guesses, not datasheets. |
| `simulate_scan.m` | **Forward model entry point.** Ties the above together and writes the frames, `meta.mat` and `truth.mat` (see below). Places neighbouring turns with variable spacing as a cutting lathe does (each turn clears its neighbour by `scene.minLand`). Runs frames in parallel with `parfor` and resumes interrupted runs. |
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

**Keyence ring (turning disc, many grooves per image)**

| File | What it does |
|---|---|
| `disc_groove_model.m` | Groove spiral on the whole disc: radius of every turn vs angle, with variable spacing and the cut audio. |
| `groove_profile.m` | Height across one groove (V with rounded bottom and edges). |
| `disc_defects_mask.m` | Scratches and dust fixed to the record, so they look the same in overlapping images. |
| `render_disc_frame.m` | Renders one VHX image of the disc at a given rotation, in true disc geometry (coaxial light, anti-aliased across the grooves; sensor noise is added afterwards). |
| `unwarp_frame.m` | Resamples an image onto angle × radius about the rig axis (with skew and lens distortion), so silent grooves run along the rows. |
| `read_grooves_polar.m` | Reads every groove of an unwarped image column by column (profile model, all columns at once) and marks columns that are not believable. |
| `estimate_polar_distortion.m` | Lens distortion and remaining skew from unwarped images: what all silent grooves share after their own straight line is removed. |
| `physical_limits.m` | Rejects groove readings no cut groove can produce: a wall moving sideways faster than a cutter can, or bending tighter than a stylus tip (plus a noise allowance). |
| `register_polar.m` | Sub-pixel shift (and radial shift) between consecutive unwarped images, starting from the motion trace. |
| `fit_spiral.m` | **The groove as one spiral:** music time → position in every image. Fits the blank spiral (variable pitch, off-centre disc) to all groove readings, gives each reading its turn number, removes each image's offset from the overlaps, and averages all views of each instant onto one time grid. Used by `retrieve_ring_polar.m`. |
| `stitch_polar_chains.m` | Older alternative to `fit_spiral.m` (not used): follows each groove image to image. |
| `extract_ring_frames.m` | Video → one ring of frames: measures the motion, finds where the first frame comes back (one revolution, which also gives the rig radius), picks well-focused frames with 20–50 % overlap and saves them with `meta.mat` (skipped if already done). |
| `retrieve_ring_polar.m` | Ring of frames → audio, fast: camera skew and lens distortion from the grooves, unwarping to angle × radius, reading straight across each groove, physical limits, registration from the motion trace, the whole spiral as one groove, audio. |
| `scan_video_motion.m` | Reads a video once: shift between consecutive frames and against the first frame (phase correlation), and a focus value; cached. |
| `phase_correlate.m` | Sub-pixel shift between two images from their Fourier transforms. |
| `select_ring_frames.m` | Finds one revolution in the motion trace and picks overlapping, well-focused frames covering it. |
| `detect_grooves_frame.m` | Both edges of every groove in an image (sub-pixel), linked from column to column into tracks. |
| `merge_groove_pieces.m` | Joins the pieces of a groove that dust or blur split apart within an image (pieces lying on the same curve). |
| `fit_groove_profiles.m` | **Model-based groove reading** (`method = 'fit'` in `retrieve_keyence_ring.m`): fits a dark band with blurred walls and a bright bottom line to every pixel across each groove, column by column, with a robust loss (dust pulls little) and a smoothness prior along the groove that only removes detail above the audio band. Gives centre, width, wall blur and an error estimate per column. |
| `correct_row_distortion.m` | Removes the bend the optics give the grooves, as a smooth surface over the image (grooves low in a VHX image bend ~2 px more than high ones); would otherwise buzz at the image rate and make overlapping images disagree. |
| `frame_to_polar.m` | Image pixels → angle and radius about the rig axis, given the camera skew. |
| `register_frames.m` | Rotation step between images and the camera skew, from the grooves themselves; also the radial creep between images. |
| `stitch_groove_chains.m` | Follows each groove through all images; with a full ring it continues one turn further in after each revolution. Aligns each groove's offset image to image and cross-fades (averages) overlapping images. |
| `correct_eccentricity.m` | Removes the once-per-revolution wobble of a disc that is off the rig axis. |
| `chain_to_audio.m` | Plays a groove chain back: centre = mono, inner edge = left, outer edge = right, with RIAA. |
| `write_chain_audio.m` | Plays back groove chains and writes them all: loudest long chain, every chain, all chains in one file, and an `_all_eq.wav` made listenable (rumble below 50 Hz removed, level set by the bulk of the signal). |
| `denoise_audio.m` | Optional clean-up (not used by default): bridges clicks, then spectral subtraction of the steady hiss. |
| `score_chain.m` | Compares a chain's audio with the simulation's truth (SNR per channel). |
| `median_omitnan.m` | Median ignoring NaN (works in Octave too). |

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

## References

Full BibTeX entries are in `docs/references.bib` (keys in brackets). Entries marked *check* have a detail not yet confirmed against the paper.

**Image-based sound recovery (closest prior work)**

Taken together: 2D edge tracking of grooves (IRENE, VisualAudio, Hensman & Casey), stereo from the two edges of a 2D image (Shikama & Mizuno), and stereo from 3D scans (McGill) have all been done. Not found so far: a physical forward model of the image formation, a quantified precision/SNR analysis against hardware choices, and a treatment of the stereo separation as an inverse problem (ambiguity between groove depth, wall angle and edge rounding).

- [fadeyev2003] Fadeyev & Haber, "Reconstruction of mechanically recorded sound by image processing", *J. Audio Eng. Soc.* 51(12), 2003 (*check* issue). Microscope images of 78 rpm grooves, edge detection, groove position → audio. The basis of IRENE (Lawrence Berkeley National Lab / Library of Congress), which scans with a line camera under coaxial light.
- [fadeyev2005] Fadeyev et al., "Reconstruction of recorded sound from an Edison cylinder using three-dimensional noncontact optical surface metrology", *J. Audio Eng. Soc.* 53(6), 2005. 3D confocal scanning for vertically cut cylinders, where a 2D image is not enough.
- [cavaglieri2001] Cavaglieri, Johnsen & Bapst, AES 20th Int. Conf., 2001 (*check* title), and [stotzer2004] Stotzer et al., "Phonographic sound extraction using image and signal processing", ICASSP 2004. VisualAudio: each disc side photographed onto film in one exposure, the film scanned on a rotating stage, sound extracted by edge detection. Targets 78s; about 20 dB SNR.
- [li2007] Li, de Leon & Fujinaga, ISMIR 2007, and [li2009] Li, Smith & Fujinaga, ISMIR 2009. First optical reconstruction of stereo LPs: 3D white-light interferometry; both top edges give lateral motion, groove-bottom depth gives vertical; L/R from their sum and difference. Demonstrated on a 1 kHz test tone; about 27 min of scanning per second of audio.
- [hensman2007] Hensman & Casey, "Optical reading and playing of sound signals from vinyl records", IT&T 2007. USB "computer microscope" + stepper motor (stop-and-shoot), least-squares stitching, colour-threshold edge tracking. Mono 78s only; no quantitative audio results.
- [tian2006] Tian, PhD thesis, Univ. of Western Ontario, 2006, and [tian2011] Tian & Barron, "Using computer vision technology to play gramophone records", *J. Audio Eng. Soc.* 59(7/8), 2011. Reconstructs groove surface orientation from images (planar-wall assumption) and decodes audio; 78 rpm-era records.
- [shikama2013] Shikama & Mizuno, "Reproduction of phonograph record sound using digital image processing" (ディジタル画像処理によるアナログレコードの音再現), *IEEJ Trans. Electronics, Information and Systems* 133(7):1309–1315, 2013. **Stereo LPs from 2D images, already done:** flatbed scanner at 6400 dpi (3.97 µm/pixel, 8-bit), Sobel edge filter, polar-to-straight unwrapping of the grooves, then the **left channel from the inner groove edge and the right channel from the outer edge** (each 45° wall carries one channel; its edge moves √2× the wall motion in plan view). Tested on a 1 kHz test-tone record: 2nd harmonic at −25 dB vs −40 dB on a turntable, audibly noisy; edge accuracy named as the main problem. Also derives the maximum groove excursion from the pitch, a = (P − W)/(4√2).
- [mizuno2016] Mizuno & Shikama, Setsunan Univ. bulletin 2(1):75–91, 2016. Same group's follow-up: compares edge filters for stereo records (LoG and DoG best); high-frequency noise remains.
- [uozumi2008] Uozumi (魚住), Hokkai-Gakuen Univ. Faculty of Engineering research report No. 35, pp. 119–129, 2008. Optical microscope + CCD camera images of 78 rpm (SP) records, mono sound extracted by image processing. Cited in shikama2013; not yet read.
- [feng2020] Feng, "Saving the Sonorine", arXiv:2005.08944, 2020. Height map from photos under several lightings (photometric stereo), compared with flatbed scans.
- [springer2002] Springer, "Digital needle", 2002 (web). A flatbed-scanned record played back in software; very noisy.

**Laser readout (no imaging)**

- [iwai1986] Iwai et al., "Reproduction of sound from old wax phonograph cylinders using the laser-beam reflection method", *Applied Optics* 25(5), 1986. Groove slope from the angle of a reflected laser beam.
- [nakamura1997] Nakamura et al., *Proc. SPIE* 3190, 1997 (*check* title). Follow-up laser method for wax cylinders; beam width limits high-frequency detail.
- [stoddard1989] Stoddard, US Patent 4,870,631, 1989. Laser turntable reading the groove walls with reflected-spot position sensing; the basis of the commercial ELP laser turntable.

**Record standard**

- [iec60098] IEC 60098:2020, *Analogue audio disk records and reproducing equipment*. Groove dimensions (90° included angle), the 45/45 stereo convention and the RIAA recording/playback curve used in `audio_to_groove.m` and `centreline_to_audio.m`.

**Physics behind the forward model**

- [cooktorrance1982] Cook & Torrance, "A reflectance model for computer graphics", *ACM Trans. Graphics* 1(1), 1982. Microfacet reflection model used in `reflectance_lut.m`.
- [beckmann1963] Beckmann & Spizzichino, *The Scattering of Electromagnetic Waves from Rough Surfaces*, 1963. Rough-surface slope distribution (`scene.roughness`).
- [zhang2007psf] Zhang, Zerubia & Olivo-Marin, *Applied Optics* 46(10), 2007. Gaussian approximation of the lens blur (σ ≈ 0.21 λ/NA) used in `camera_optics.m`.
- [thompson2002] Thompson, Larson & Webb, *Biophysical J.* 82(5), 2002. How precisely a blurred feature can be located given photons and noise; the theory behind sub-pixel edge positions.

**Inverse problems**

- [hansen2010] Hansen, *Discrete Inverse Problems: Insight and Algorithms*, SIAM, 2010. Regularisation, deconvolution, noise vs resolution trade-offs.
- [kaipio2005] Kaipio & Somersalo, *Statistical and Computational Inverse Problems*, Springer, 2005. Bayesian/statistical framing: priors, uncertainty, identifiability.

**Hardware**

- [collins2020] Collins et al., "Robotic microscopy for everyone: the OpenFlexure microscope", *Biomedical Optics Express* 11(5), 2020. Open-source 3D-printed microscope with a reflection-illumination (beamsplitter) module; a template for a DIY coaxial-light camera head.
