%% Forward path: a ring of Keyence VHX images around a record
% Simulates what the Keyence VHX records when the disc sits on a rig that
% turns it step by step under the lens, with the grooves running along
% the long side of the image. Each image shows every turn inside the
% field (about 40 at 50x). One full ring of overlapping images covers
% that many revolutions of continuous music.
%
% Includes: true spiral geometry (curved grooves, variable groove spacing),
% stereo + RIAA cutting, the rig's rotation steps with random error, an
% off-centre disc, a slightly skewed camera, dust and scratches fixed to
% the record (identical in overlapping images), lens blur, sensor noise.
% Writes data/keyence_ring/: frame_00001.png ... (8-bit greyscale, like
% the VHX), meta.mat (what the experimenter knows) and truth.mat.
%
% Time: a full 2048x1536 frame takes roughly 1-3 min per core in MATLAB
% (estimate). Frames run in parallel (parfor) and finished frames are
% kept, so the script can be stopped and restarted. Set nFrames small or
% shrink cam.imageSize to try it out.
% Lengths in micrometres (um) unless stated.

clear; close all; clc;

audioFile = fullfile(project_root(), 'data', 'brahms_hungarian_dance_5.ogg');
outDir = fullfile(project_root(), 'data', 'keyence_ring');

%% 1. Setup

scene = default_scene();
cam = camera_preset('keyenceVHX', 50);   % zoom; pixel = 148.8/zoom um
% cam.imageSize = [384 512];             % uncomment for a quick test
light.type = 'coaxial';

% Rig
Rcam = 140000;          % image centre, distance from the rig's axis (um)
overlap = 0.2;          % fraction of each image shared with the next
stepError = 0.03;       % rms error of each rotation step (fraction of a step)
ecc = [60 -25];         % disc centre offset from the rig's axis (um)
align = deg2rad(0.3);   % camera skew relative to the groove direction
nFrames = 3;            % a full ring is printed below; set nFrames to that

% Music: which moment sits at the centre of the first image
tCentre = 23;           % s into the recording

%% 2. Groove spiral and poses

[sig, fs] = load_clip(audioFile, 0, Inf);
fieldTurns = cam.imageSize(1) * cam.pixel / scene.pitch;
nPad = ceil(fieldTurns / 2) + 2;
gm = disc_groove_model(sig, fs, scene, Rcam, tCentre, nPad);

step = (1 - overlap) * cam.imageSize(2) * cam.pixel / Rcam;     % rad
nRing = ceil(2*pi / step);
step = 2*pi / nRing;          % whole number of steps per revolution
fprintf('%.2f um/pixel, %.1f x %.1f mm field, ~%.0f turns per image\n', ...
    cam.pixel, cam.imageSize(2)*cam.pixel/1e3, cam.imageSize(1)*cam.pixel/1e3, fieldTurns);
fprintf('A full ring is %d images (%.0f%% overlap)\n', nRing, ...
    100 * (1 - step * Rcam / (cam.imageSize(2) * cam.pixel)));

rng(7);
phi0 = (tCentre + gm.tMusic) / gm.T * 2*pi;          % angle of that moment
phi = phi0 + step * ((0:nFrames-1) + stepError * randn(1, nFrames));

%% 3. Render

if ~exist(outDir, 'dir'), mkdir(outDir); end
groups = light_sources(light, cam);
for g = 1:numel(groups)
    luts(g) = reflectance_lut(groups(g), cam, scene);         %#ok<SAGROW>
end
landLevel = 0;
for g = 1:numel(groups)
    landLevel = landLevel + interp2(luts(g).nx, luts(g).ny, luts(g).S, 0, 0);
end
exposure = 0.85 * cam.fullWell / (landLevel * (1 + cam.glare));   % fixed, like a locked exposure

tic;
parfor k = 1:nFrames
    file = fullfile(outDir, sprintf('frame_%05d.png', k));
    if exist(file, 'file'), continue; end
    pose = struct('phi', phi(k), 'Rcam', Rcam, 'ecc', ecc, 'align', align);
    P = render_disc_frame(gm, pose, cam, scene, groups, luts, landLevel);
    rng(k);
    DN = camera_sensor(P, cam, exposure);
    imwrite(uint8(round(DN)), file);
    fprintf('  frame %d done\n', k);
end
fprintf('Rendered %d frames in %.1f min\n', nFrames, toc/60);

%% 4. Save what the experimenter knows, and the truth

meta.cam = cam;  meta.scene = scene;  meta.light = light;
meta.nominalStep = step;  meta.overlap = overlap;  meta.Rcam = Rcam;
meta.nFrames = nFrames;
save(fullfile(outDir, 'meta.mat'), '-struct', 'meta');

truth.phi = phi;  truth.ecc = ecc;  truth.align = align;  truth.Rcam = Rcam;
truth.gm = gm;  truth.audio = sig;  truth.fsAudio = fs;  truth.tCentre = tCentre;
save(fullfile(outDir, 'truth.mat'), '-struct', 'truth', '-v7');

%% 5. Show the first image

I = imread(fullfile(outDir, 'frame_00001.png'));
figure('Color', 'w');
imagesc((0:size(I, 2)-1) * cam.pixel, (0:size(I, 1)-1) * cam.pixel, I);
axis image;  colormap(gray(256));
xlabel('Along the grooves (\mum)');  ylabel('Across the grooves (\mum)');
title(sprintf('Simulated Keyence VHX image, %dx', cam.magnification));
