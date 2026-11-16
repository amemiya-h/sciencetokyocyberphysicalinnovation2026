%% Retrieval: a ring of Keyence images -> grooves -> stereo audio
% Works on images with the grooves running left-right along the long
% side, dark grooves on bright land (coaxial light), outer edge of the
% record at the top, taken while the rig turns the disc step by step.
%
%   1. In every image, find both edges of every groove (sub-pixel).
%   2. Line consecutive images up: in polar coordinates about the rig axis
%      they differ only by the rotation step; the camera skew is found
%      from how well the overlaps agree.
%   3. Follow each groove through the images. With a full ring, a groove
%      continues one turn further in after each revolution, so one chain
%      plays for as many revolutions as there are grooves in view.
%   4. Correct the wow from an off-centre disc (full ring only).
%   5. Play back in stereo: inner edge = left, outer edge = right,
%      centre = mono, with RIAA. WAVs go to results/runs/.
%   6. If the images are simulated (truth.mat present), score the result.
%
% Data sets: 'keyence_ring' (simulated, forward_keyence_ring.m) or a
% folder written by extract_ring_frames.m from a real recording, e.g.
% 'keyence_recording/20261027_184833'. For other real images, fill in
% section 0 by hand. Lengths in micrometres (um).

clear; close all; clc;

dataset = 'keyence_ring';
method = 'fit';      % 'fit': fit a groove model to all pixels across each groove
                     % (fit_groove_profiles); 'edges': steepest points only
dataDir = fullfile(project_root(), 'data', dataset);
runsDir = fullfile(project_root(), 'results', 'runs');
tag = regexprep(dataset, '.*/', '');
if ~exist(runsDir, 'dir'), mkdir(runsDir); end
logFile = fullfile(runsDir, [tag '_log.txt']);
if exist(logFile, 'file'), delete(logFile); end
diary(logFile);                 % everything printed also goes to this file
audioOpts = struct('band', [20 20e3], 'fsOut', 48e3);

%% 0. What we know about the setup

regOpts = struct();
if exist(fullfile(dataDir, 'meta.mat'), 'file')
    meta = load(fullfile(dataDir, 'meta.mat'));
    cam = meta.cam;  Rcam = meta.Rcam;  nominalStep = meta.nominalStep;
    if isfield(meta, 'scene')                % simulated
        scene = meta.scene;
        grooveWidth = 2 * scene.depth * tand(scene.includedAngle/2);
        pitch = scene.pitch;  rpm = scene.rpm;
    else                                     % from extract_ring_frames.m
        grooveWidth = meta.grooveWidth;  pitch = meta.pitch;  rpm = meta.rpm;
        regOpts = meta.regOpts;
    end
else
    % Real images: set these by hand
    cam.pixel = 148.8 / 50;         % um per pixel (check with the scale bar)
    Rcam = 140000;                  % image centre from the rig axis (um)
    nominalStep = deg2rad(2.0);     % intended rotation between images
    grooveWidth = 76;               % measured groove width (um)
    pitch = 120;                    % typical groove spacing (um)
    rpm = 100/3;
end
files = dir(fullfile(dataDir, 'frame_*.*'));
files = files(~[files.isdir]);
[~, order] = sort({files.name});
files = files(order);
N = numel(files);
I1 = imread(fullfile(dataDir, files(1).name));
cam.imageSize = [size(I1, 1), size(I1, 2)];
if isscalar(nominalStep)
    ring = N * nominalStep >= 2*pi - 0.5*nominalStep;
else
    ring = numel(nominalStep) == N;      % one step per pair incl. N -> 1
end
fprintf('%d images, %.2f um/pixel, %s\n', N, cam.pixel, ...
    ternary(ring, 'full ring', 'partial ring'));

%% 1. Grooves in every image

detOpts = struct('expectedWidth', grooveWidth);
tracks = cell(1, N);
tic;
parfor k = 1:N
    I = double(imread(fullfile(dataDir, files(k).name)));
    if size(I, 3) == 3, I = mean(I, 3); end
    tracks{k} = detect_grooves_frame(I / 255, cam, detOpts);
end
fprintf('Detected grooves in %.0f s (median %d per image)\n', toc, ...
    median(cellfun(@(t) size(t.outer, 1), tracks)));
% join pieces of a groove that dust or blur split apart
tracks = merge_groove_pieces(tracks, cam, Rcam);
if strcmp(method, 'fit')
    % centre and width of every groove from a model of its whole profile
    tic;
    fitOpts = struct('pitch', pitch);
    parfor k = 1:N
        I = double(imread(fullfile(dataDir, files(k).name)));
        if size(I, 3) == 3, I = mean(I, 3); end
        tracks{k} = fit_groove_profiles(I / 255, tracks{k}, cam, fitOpts);
    end
    sig = cell2mat(cellfun(@(t) t.sigma(:), tracks(:), 'UniformOutput', false));
    cs = cell2mat(cellfun(@(t) t.cStd(:), tracks(:), 'UniformOutput', false));
    fprintf('Fitted groove profiles in %.0f s: wall blur %.2f px, centre error ~%.2f um per column\n', ...
        toc, median(sig(~isnan(sig))), median(cs(~isnan(cs))) * cam.pixel);
end
% the optics bend the grooves the same way in every image: take it out
[tracks, bend] = correct_row_distortion(tracks, cam, Rcam);
if ~isempty(bend)
    fprintf('Fixed groove bend from the optics: %.2f px peak-to-peak\n', max(bend(:)) - min(bend(:)));
end

nT = cellfun(@(t) size(t.outer, 1), tracks);
W = cam.imageSize(2);
nFull = cellfun(@(t) sum(mean(~isnan(t.outer), 2) >= 0.9), tracks);
part = cellfun(@(t) sum(mean(~isnan(t.outer), 2) < 0.5), tracks);
fprintf(['  per image: %d..%d tracks; covering >=90%% of the width: median %d; ' ...
         'fragments (<50%%): median %d, max %d (image %d)\n'], min(nT), max(nT), ...
         median(nFull), median(part), max(part), find(part == max(part), 1));

%% 2. Line the images up

tic;
regOpts.pitch = pitch;  regOpts.ring = ring;
reg = register_frames(tracks, cam, Rcam, nominalStep, regOpts);
fprintf('Registered in %.0f s: camera skew %.3f deg, steps %.4f +/- %.4f deg\n', ...
    toc, rad2deg(reg.alpha), rad2deg(mean(reg.step)), rad2deg(std(reg.step)));

% Diagnostics: how well each pair of images joined up
nA = cellfun(@(t) size(t.outer, 1), tracks(reg.pairs(:, 1)));
nM = cellfun(@(m) nnz(m), reg.match);
fracM = nM(:)' ./ max(nA(:)', 1);
dStep = rad2deg(reg.step - nominalStep);
fprintf('  matched grooves per pair: median %.0f%%, worst %.0f%%; cost median %.2f um, worst %.2f um\n', ...
    100*median(fracM), 100*min(fracM), median(reg.cost), max(reg.cost));
fprintf('  step - motion estimate: median %.4f deg, rms %.4f deg, worst %.4f deg (pair %d)\n', ...
    median(dStep), sqrt(mean(dStep.^2)), max(abs(dStep)), find(abs(dStep) == max(abs(dStep)), 1));
if isfield(regOpts, 'offset0')
    dOff = reg.offset - regOpts.offset0;
    fprintf('  radial shift - motion estimate: rms %.1f um, worst %.1f um (pair %d)\n', ...
        sqrt(mean(dOff.^2)), max(abs(dOff)), find(abs(dOff) == max(abs(dOff)), 1));
end
[~, worst] = sort(fracM);
fprintf('  10 worst pairs [pair, frames, matched/tracks, cost um, step error deg, offset um]:\n');
for q = worst(1:min(10, end))
    fprintf('    %3d  %3d->%3d  %2d/%2d  %6.2f  %+.4f  %+6.1f\n', q, reg.pairs(q, 1), reg.pairs(q, 2), ...
        nM(q), nA(q), reg.cost(q), dStep(q), reg.offset(q));
end

%% 3-4. Follow the grooves; correct the off-centre disc

chains = stitch_groove_chains(tracks, reg, cam, Rcam);
% Diagnostics: chain lengths and where chains end
len = arrayfun(@(c) size(c.nodes, 1), chains);
fprintf('  chains: %d; frames per chain: median %d, 90th pct %d, max %d (ring = %d frames)\n', ...
    numel(chains), median(len), sort_pct(len, 90), max(len), N);
lastF = arrayfun(@(c) c.nodes(end, 1), chains(len >= 3));
cnt = accumarray(lastF(:), 1, [N 1])';
[~, ord] = sort(cnt, 'descend');
fprintf('  frames where most chains (>= 3 frames long) end: %s (counts %s)\n', ...
    mat2str(ord(1:min(10, end))), mat2str(cnt(ord(1:min(10, end)))));
if ring
    [chains, ecc] = correct_eccentricity(chains);
    fprintf('Disc offset from the rig axis: %.1f um\n', ecc.e);
end
T = 60 / rpm;
dur = arrayfun(@(c) (c.theta(end) - c.theta(1)) / (2*pi) * T, chains);
fprintf('%d groove chains; longest %.2f s, total %.1f s of groove\n', ...
    numel(chains), max(dur), sum(dur));
% Sanity check: playing along the groove, it must spiral inward
c1 = chains(1);  ok = ~isnan(c1.centre);
q = polyfit(c1.theta(ok) / (2*pi), c1.centre(ok), 1);
fprintf('Longest groove moves %+.1f um per turn (expect about -%.0f)\n', q(1), pitch);
if dur(1) > 1.5 * T && q(1) > 0
    warning(['The groove spirals outward: the images are probably mirrored ' ...
             '(or the disc turned backwards).']);
end

%% 5. Play back: the loudest long chain, every chain, and all of them

best = write_chain_audio(chains, T, audioOpts, runsDir, tag);

% Everything needed to look at or redo any step without rerunning it
save(fullfile(runsDir, [tag '_result.mat']), 'tracks', 'reg', 'chains', 'dur', ...
    'cam', 'Rcam', 'nominalStep', 'regOpts', 'grooveWidth', 'pitch', 'rpm', ...
    'audioOpts', 'best', '-v7.3');
fprintf('Saved tracks, registration and chains to %s_result.mat\n', tag);

%% 6. Score against the simulation's truth

if exist(fullfile(dataDir, 'truth.mat'), 'file')
    truth = load(fullfile(dataDir, 'truth.mat'));
    truth.depth = scene.depth;
    fprintf('True skew %.3f deg; step error rms %.4f deg\n', rad2deg(truth.align), ...
        rad2deg(sqrt(mean((reg.step(1:N-1) - diff(truth.phi)).^2))));
    for c = 1:min(5, numel(chains))
        ac = chain_to_audio(chains(c), T, audioOpts);
        s = score_chain(chains(c), ac, truth, T, audioOpts);
        fprintf(['chain %d (%.2f s): centre error %.3f um, SNR mono %.1f / L %.1f / ' ...
                 'R %.1f / L-R %.1f dB\n'], c, dur(c), ...
                 s.rmsCentre, s.snrMono, s.snrLeft, s.snrRight, s.snrSide);
    end
end

diary off;

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function v = sort_pct(x, p)
x = sort(x(:));
v = x(max(1, round(p/100 * numel(x))));
end
