function res = retrieve_ring_polar(dataDir, opts)
%RETRIEVE_RING_POLAR  A ring of groove images -> audio (fast, unwarped).
%   res = RETRIEVE_RING_POLAR(dataDir, opts) reads a folder written by
%   extract_ring_frames (frame_*.png + meta.mat) and writes audio. It is
%   organised around the silent spiral:
%
%   1. Camera skew and lens distortion, from a sample of images: with the
%      right geometry, a silent groove is a straight row once the image is
%      resampled to angle x radius about the rig axis ("unwarped").
%   2. Unwarp every image and read every groove column by column, straight
%      across the groove (perpendicular to the silent spiral), by fitting
%      a model of the groove's brightness profile. Columns the model does
%      not explain are rejected, and so are readings a cut groove cannot
%      produce: a wall moving sideways faster than a cutter can (0.3 m/s)
%      or bending tighter than a stylus tip (10 um radius). Rejected
%      readings are left out, not smoothed over.
%   3. Line consecutive images up: they now differ only by a shift along
%      the groove (from the video's motion trace, refined to sub-pixel)
%      and a small radial shift.
%   4. Model the groove as one spiral, music time -> position in every
%      image (fit_spiral): turn numbers from the spiral, the off-centre
%      disc inside the model, all views of each instant averaged.
%   5. Play back (inner edge = left, outer = right, centre = mono, RIAA)
%      and write every chain, all chains together, an EQ'd version to
%      listen to (<tag>_all_eq.wav), a log and a .mat with everything.
%
%   Lengths in micrometres (um), image positions in pixels (px).
%
%   opts fields (defaults in brackets)
%     runsDir   where outputs go [results/runs]
%     tag       output name prefix [<folder name>_polar]
%     vMax, rhoMin   physical limits of the cut (m/s, um) [0.3, 10]
%     redo      read the images again even if dataDir/grooves.mat holds
%               the geometry and grooves from an earlier run [false]
%
%   res: struct with chains, reg, G (grooves per image), alpha, prof,
%   the played chain (best) and the output folder and tag.

if nargin < 2, opts = struct(); end
[~, folder] = fileparts(dataDir);
def = struct('runsDir', fullfile(project_root(), 'results', 'runs'), ...
             'tag', [folder '_polar'], 'vMax', 0.3, 'rhoMin', 10, 'redo', false);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end
runsDir = opts.runsDir;  tag = opts.tag;
if ~exist(runsDir, 'dir'), mkdir(runsDir); end
logFile = fullfile(runsDir, [tag '_log.txt']);
if exist(logFile, 'file'), delete(logFile); end
diary(logFile);
cleanup = onCleanup(@() diary('off'));
audioOpts = struct('band', [20 20e3], 'fsOut', 48e3);
tStart = tic;

%% 0. Setup (meta.mat from extract_ring_frames.m)

meta = load(fullfile(dataDir, 'meta.mat'));
cam = meta.cam;  Rcam = meta.Rcam;  nominalStep = meta.nominalStep;
pitch = meta.pitch;  grooveWidth = meta.grooveWidth;  rpm = meta.rpm;
files = dir(fullfile(dataDir, 'frame_*.png'));
[~, order] = sort({files.name});
files = files(order);
N = numel(files);
H = cam.imageSize(1);  W = cam.imageSize(2);
ring = numel(nominalStep) == N;
pixAng = cam.pixel / Rcam;
readOpts = struct('pitch', pitch, 'width', grooveWidth);
if ring, kind = 'full ring'; else, kind = 'partial ring'; end
fprintf('%d images, %.2f um/pixel, %s\n', N, cam.pixel, kind);

cacheFile = fullfile(dataDir, 'grooves.mat');     % the slow part, kept
fmt = '-v7.3';                                     % large files (MATLAB)
if exist('OCTAVE_VERSION', 'builtin'), fmt = '-v7'; end
cached = false;
if ~opts.redo && exist(cacheFile, 'file')
    C = load(cacheFile);
    if numel(C.G) == N
        alpha = C.alpha;  prof = C.prof;  G = C.G;  cached = true;
        fprintf('Using the geometry and grooves saved in %s (opts redo = true to redo)\n', cacheFile);
    end
end
if ~cached
%% 1. Camera skew and lens distortion from a sample of images

tic;
t1 = detect_grooves_frame(load_image(dataDir, files, 1), cam, struct('expectedWidth', grooveWidth));
sl = [];
for i = 1:size(t1.outer, 1)
    c = (t1.outer(i, :) + t1.inner(i, :)) / 2;  ok = ~isnan(c);
    if nnz(ok) > 0.5 * W, q = polyfit(find(ok), c(ok), 1); sl(end+1) = q(1); end %#ok<SAGROW>
end
alpha = atan(median(sl));                      % first guess: groove slope
prof = zeros(H, W);
sample = unique(round(linspace(1, N, min(N, 24))));
for it = 1:3
    Gs = cell(1, numel(sample));
    parfor s = 1:numel(sample)
        P = unwarp_frame(load_image(dataDir, files, sample(s)), cam, Rcam, alpha, prof);
        Gs{s} = read_grooves_polar(P, cam, readOpts);
    end
    [dprof, slope] = estimate_polar_distortion(Gs, H, W);
    alpha = alpha + atan(slope);               % grooves must come out flat
    prof = prof + dprof;
    fprintf('  geometry pass %d: skew %.3f deg (slope left %.1e), distortion %.2f px p-p\n', ...
        it, rad2deg(alpha), slope, max(prof(:)) - min(prof(:)));
end
fprintf('Camera skew %.3f deg, lens distortion %.2f px peak-to-peak (%.0f s)\n', ...
    rad2deg(alpha), max(prof(:)) - min(prof(:)), toc);

%% 2. Unwarp and read every image

tic;
G = cell(1, N);
parfor k = 1:N
    P = unwarp_frame(load_image(dataDir, files, k), cam, Rcam, alpha, prof);
    g = read_grooves_polar(P, cam, readOpts);
    g.c = single(g.c);  g.w = single(g.w);  g.res = single(g.res);
    G{k} = g;
end
nL = cellfun(@(g) numel(g.row0), G);
good = cellfun(@(g) mean(g.ok(:)), G);
fprintf('Read %d images in %.0f s: %d..%d grooves each, %.1f%% of columns good (worst image %d: %.0f%%)\n', ...
    N, toc, min(nL), max(nL), 100*mean(good), find(good == min(good), 1), 100*min(good));
save(cacheFile, 'alpha', 'prof', 'G', fmt);
fprintf('Saved geometry and grooves to %s\n', cacheFile);
end

% Physical limits of a cut groove: reject readings no cutter could make
[G, lim] = physical_limits(G, cam, Rcam, 60 / rpm, struct('vMax', opts.vMax, 'rhoMin', opts.rhoMin));
fprintf('Physical limits rejected %.2f%% of columns (slope %.2f%%, curvature %.2f%%)\n', ...
    100*(lim.slope + lim.curvature), 100*lim.slope, 100*lim.curvature);

%% 3. Line the images up

tic;
nominalCols = nominalStep * Rcam / cam.pixel;
rows0 = [];
if isfield(meta, 'regOpts') && isfield(meta.regOpts, 'offset0')
    rows0 = -meta.regOpts.offset0 / cam.pixel;  % radius grows upward
end
reg = register_polar(G, nominalCols, struct('pitchPx', pitch / cam.pixel, ...
    'searchPx', 8, 'rows0', rows0, 'ring', ring));
if ring
    reg.shift = reg.shift * ((2*pi / pixAng) / sum(reg.shift));
end
nA = cellfun(@(g) numel(g.row0), G(reg.pairs(:, 1)));
fracM = cellfun(@(m) nnz(m), reg.match) ./ max(nA, 1);
dShift = reg.shift - nominalCols;
fprintf(['Registered in %.0f s: shift - motion trace %.2f px rms; matched grooves ' ...
         'median %.0f%%, worst %.0f%% (pair %d); mismatch median %.2f um, worst %.2f um\n'], ...
    toc, sqrt(mean(dShift.^2)), 100*median(fracM), 100*min(fracM), find(fracM == min(fracM), 1), ...
    median(reg.cost) * cam.pixel, max(reg.cost) * cam.pixel);

%% 4. The spiral: music time -> position in every image

tic;
[sp, chain] = fit_spiral(G, reg, cam, Rcam, struct('ring', ring));
chains = chain;
T = 60 / rpm;
dur = (chain.theta(end) - chain.theta(1)) / (2*pi) * T;
v = sp.nViews(sp.nViews > 0);
fprintf(['Spiral (%.0f s): %d turns, %.1f s of music, groove spacing %.1f um/turn, ' ...
         'disc off-centre by %.1f um; views per sample: median %d, %.1f%% of samples unseen\n'], ...
    toc, sp.turns, dur, sp.pitch, sp.ecc.e, median(v), 100 * mean(sp.nViews == 0));

%% 5. Play back and save everything

best = write_chain_audio(chains, T, audioOpts, runsDir, tag);
save(fullfile(runsDir, [tag '_result.mat']), 'G', 'reg', 'sp', 'chains', 'dur', 'alpha', ...
    'prof', 'cam', 'Rcam', 'nominalStep', 'pitch', 'grooveWidth', 'rpm', 'audioOpts', ...
    'best', fmt);
fprintf('Saved everything to %s_result.mat. Total %.0f s\n', tag, toc(tStart));
res = struct('chains', chains, 'sp', sp, 'reg', reg, 'alpha', alpha, 'prof', prof, ...
             'best', best, 'runsDir', runsDir, 'tag', tag);
res.G = G;
end

function I = load_image(dataDir, files, k)
I = mean(double(imread(fullfile(dataDir, files(k).name))), 3) / 255;
end
