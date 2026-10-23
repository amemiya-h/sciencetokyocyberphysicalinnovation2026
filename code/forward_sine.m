%% Forward path: test-tone groove -> simulated camera frames in data/sine/
% Same physics as forward_music.m, cutting a steady 1 kHz tone like a
% test record. Quick to run; useful for checking the retrieval.
% Lengths in micrometres (um) unless stated.

clear; close all; clc;

outDir = fullfile(project_root(), 'data', 'sine');

%% 1. Setup

f0 = 1000;           % tone (Hz)
clipLength = 0.02;   % s

scene = default_scene();
scene.stereo = false;      % mono tone: no vertical motion
scene.peakLateral = 8;     % um; about 5 cm/s at 1 kHz, a common reference level
cam = camera_preset('telecentric2x');
light.type = 'coaxial';
frameRows = 250;

%% 2. Simulate the scan

fs = 48e3;
margin = scene.nNeighbours * 60/scene.rpm + 0.05;
t = (0 : 1/fs : clipLength + 2*margin)';
sig = sin(2*pi*f0*t);

simulate_scan(sig, fs, margin, clipLength, scene, cam, light, outDir, frameRows);
fprintf('Wrote %s\n', outDir);

%% 3. Figures

% Groove surface around the scanned groove
x = -scene.halfWidth:0.5:scene.halfWidth;
y = (0:0.5:400)';
speed = 2*pi*scene.radius * scene.rpm/60 * 1e6;
lambda = speed / f0;
xc = scene.peakLateral * sin(2*pi*y/lambda);
centres = xc + (-scene.nNeighbours:scene.nNeighbours) * scene.pitch;
Z = groove_surface(x, centres, scene.depth * ones(size(centres)), scene);
plot_groove(x, y, Z);

% First frame
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
