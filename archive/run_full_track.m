%% End to end on the whole recording: music -> simulated scan -> audio
% Cuts the full Brahms recording into a groove, renders every camera frame
% (forward path, written to data/full_<camera>/), then tracks the groove
% through all frames and plays it back (retrieval path), and writes the
% true and recovered audio to results/runs/ for listening.
%
% Size and time, for the default telecentric2x camera:
%   ~42 s of music, ~13 million pixel rows, ~5 GB of frames.
%   Rendering is the slow part: roughly 0.5 s per 1000-row frame per CPU
%   core in MATLAB (an estimate; it was ~1.5 s in Octave), so a few hours
%   on one core, much less with the Parallel Computing Toolbox (parfor).
%   It can be stopped and restarted: finished frames are kept.
%   Tracking takes a further ~20-40 min on one core.
% To try it first, set clipLength to a few seconds.

clear; close all; clc;

audioFile = fullfile(project_root(), 'data', 'brahms_hungarian_dance_5.ogg');

scene = default_scene();
cam = camera_preset('telecentric2x');    % see camera_preset
light.type = 'coaxial';
frameRows = 1000;

% The whole track, minus one revolution at each end for the neighbouring turns
info = audioinfo(audioFile);
margin = scene.nNeighbours * 60/scene.rpm + 0.05;
clipLength = info.Duration - 2*margin;   % s; set e.g. 5 for a quick test

outDir = fullfile(project_root(), 'data', ['full_' cam.name]);
runsDir = fullfile(project_root(), 'results', 'runs');

%% 1. Forward path: render the frames

speed = 2*pi*scene.radius * scene.rpm/60 * 1e6;            % um/s
nRows = floor(clipLength * speed / cam.pixel);
fprintf('%.1f s of music -> %d rows, %d frames (~%.1f GB)\n', clipLength, ...
    nRows, ceil(nRows/frameRows), nRows / 2.6e6);

[sig, fs] = load_clip(audioFile, 0, clipLength + 2*margin);
tic;
simulate_scan(sig, fs, margin, clipLength, scene, cam, light, outDir, frameRows);
fprintf('Forward path took %.1f min\n', toc/60);

%% 2. Retrieval path: track, play back, score

trackOpts = struct('widthTolerance', 0.5, 'trackingWindow', 8, 'startCentre', 0);
audioOpts = struct('band', [20 20e3], 'fsOut', 48e3);

tic;
r = retrieve_audio(outDir, trackOpts, audioOpts);
fprintf('Retrieval took %.1f min\n', toc/60);

fprintf('\nRows with a detected edge pair: %.1f%%\n', 100*r.coverage);
fprintf('Centreline RMSE: %.3f um\n', r.rmseDetected);
fprintf('Audio SNR against a perfect stylus: %.1f dB\n', r.snr);

%% 3. Listen

if ~exist(runsDir, 'dir'), mkdir(runsDir); end
scale = 0.9 / max(abs([r.ref.audio; r.est.audio]));
name = ['full_' cam.name];
audiowrite(fullfile(runsDir, [name '_true.wav']), scale*r.ref.audio, r.ref.fs);
audiowrite(fullfile(runsDir, [name '_recovered.wav']), scale*r.est.audio, r.est.fs);
fprintf('Wrote %s_true.wav and %s_recovered.wav to %s\n', name, name, runsDir);

plot_audio(r.ref, r.est, [10, 10.02]);
