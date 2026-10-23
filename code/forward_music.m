%% Forward path: music -> groove -> simulated camera frames in data/music/
% Cuts a clip of a recording into a groove the way a lathe would (RIAA,
% 45/45 stereo), places the neighbouring turns beside it, and renders what
% a camera would see: vinyl reflectance, lens aperture and blur, lighting,
% shadows, dust, pixel size and sensor noise. Writes the frames for
% retrieve_centreline.m. Lengths in micrometres (um) unless stated.
%
% Music: Brahms, Hungarian Dance No. 5, The U.S. Army Strings. Public
% domain; see data/brahms_hungarian_dance_5_LICENSE.txt.

clear; close all; clc;

audioFile = fullfile(project_root(), 'data', 'brahms_hungarian_dance_5.ogg');
outDir = fullfile(project_root(), 'data', 'music');

%% 1. Setup

clipStart = 10;      % s into the recording
clipLength = 0.5;    % s; about 1-2 min of rendering per 0.1 s

scene = default_scene();                 % record, groove, surface, dust
cam = camera_preset('telecentric2x');    % see camera_preset for options
light.type = 'coaxial';                  % 'coaxial', 'side' or 'ring'
light.angle = 45;                        % side/ring: from vertical (deg)
light.size = 2;                          % side/ring: angular radius (deg)
light.n = 8;                             % ring: number of LEDs
frameRows = 250;                         % pixel rows per frame

%% 2. Simulate the scan

% The neighbouring turns were cut one revolution earlier/later
margin = scene.nNeighbours * 60/scene.rpm + 0.05;
[sig, fs] = load_clip(audioFile, clipStart - margin, clipLength + 2*margin);

tic;
simulate_scan(sig, fs, margin, clipLength, scene, cam, light, outDir, frameRows);
fprintf('Wrote %s in %.0f s\n', outDir, toc);

%% 3. Figure: the first frame

meta = load(fullfile(outDir, 'meta.mat'));
I = read_groove_frame(outDir, meta, 1);
figure('Color', 'w');
imagesc(meta.x, meta.y(1:size(I, 1)), I);
set(gca, 'YDir', 'normal');
axis image;
colormap(gray(256));
colorbar;
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title(sprintf('Simulated frame: %s, %s light', cam.name, light.type));
