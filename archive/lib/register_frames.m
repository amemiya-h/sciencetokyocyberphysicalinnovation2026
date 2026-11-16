function reg = register_frames(tracks, cam, Rcam, nominalStep, opts)
%REGISTER_FRAMES  Rotation steps between frames and the camera skew.
%   reg = REGISTER_FRAMES(tracks, cam, Rcam, nominalStep, opts) uses the
%   grooves themselves to line frames up. In polar coordinates about the
%   rig's axis, two consecutive images of the turning disc differ only by
%   the rotation step; the grooves must coincide where the images
%   overlap. A camera skew (alpha) would tilt each image's grooves, so it
%   is found as the single value that makes overlaps agree best.
%
%   Inputs
%     tracks       cell array, one detect_grooves_frame result per frame
%     cam          pixel, imageSize
%     Rcam         image centre distance from the rig axis (um)
%     nominalStep  intended rotation per frame (rad); a scalar, or one
%                  value per pair (e.g. from the video's motion trace)
%     opts         fields (defaults in brackets):
%       pitch      typical groove spacing (um) [120]
%       search     step search range, fraction of nominalStep [0.15]
%       searchPx   if given, search only +/- this many pixels around
%                  nominalStep (use when the steps come from the video's
%                  motion trace, which is good to a pixel or two) [NaN]
%       alpha0     starting guess for the skew (rad) [NaN: from the slope
%                  of the grooves in the images]
%       alphaMax   skew searched within alpha0 +/- alphaMax (deg) [0.3].
%                  Keep it small: a skew error that shifts the far side of
%                  the overlap by one groove spacing fits almost as well
%                  (the grooves look alike), so a wide search can lock on
%                  the neighbouring groove
%       ring       also register the last frame to the first, and scale
%                  the steps to add up to exactly 2*pi [false]
%       nAlphaPairs  frame pairs used to find the skew [5]
%       offset0    expected radial shift of frame k+1's grooves relative
%                  to frame k (um), one value per pair [zeros]; nonzero
%                  when the disc crept radially, e.g. over a whole ring
%
%   Output struct reg
%     alpha     camera skew (rad)
%     step      1 x nPairs rotation from frame k to k+1 (rad); with ring,
%               the last entry is from the last frame back to the first
%     match     1 x nPairs cell; match{k}(i) = track in frame k+1 that
%               continues track i of frame k (0 if none)
%     cost      1 x nPairs median |radius difference| at the optimum (um)
%     offset    1 x nPairs common radial shift (um) of frame k+1's grooves
%               relative to frame k's at the optimum

def = struct('pitch', 120, 'search', 0.15, 'alphaMax', 0.3, 'alpha0', NaN, 'ring', false, ...
             'nAlphaPairs', 5, 'offset0', [], 'searchPx', NaN);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end

N = numel(tracks);
pairs = [(1:N-1)', (2:N)'];
if opts.ring
    pairs(end+1, :) = [N, 1];
end
nP = size(pairs, 1);
if isscalar(nominalStep), nominalStep = repmat(nominalStep, 1, nP); end
off0 = opts.offset0;
if isempty(off0), off0 = zeros(1, nP); end

% 1. Rotation steps from the shape of the groove wiggles alone, at the
%    starting skew. A skew error shifts the overlapping grooves radially
%    by a constant amount, so that offset is removed here and used for
%    the skew in step 2.
use = round(linspace(1, nP, min(opts.nAlphaPairs, nP)));
if isnan(opts.alpha0)
    opts.alpha0 = groove_slope(tracks(unique(pairs(use, :))));
end
reg.step = zeros(1, nP);
for k = 1:nP
    reg.step(k) = best_step(tracks{pairs(k,1)}, tracks{pairs(k,2)}, cam, Rcam, ...
                            opts.alpha0, nominalStep(k), off0(k), opts);
end

% 2. Camera skew: the value that makes the overlapping grooves coincide
alphas = opts.alpha0 + deg2rad(-opts.alphaMax : 0.01 : opts.alphaMax);
C = zeros(size(alphas));
for a = 1:numel(alphas)
    for k = use
        [thA, rA] = centre_polar(tracks{pairs(k,1)}, cam, Rcam, alphas(a));
        [thB, rB] = centre_polar(tracks{pairs(k,2)}, cam, Rcam, alphas(a));
        [~, ~, off] = overlap_cost(thA, rA, thB + reg.step(k), rB, opts.pitch, off0(k));
        C(a) = C(a) + abs(off - off0(k));
    end
end
[~, ia] = min(C);
reg.alpha = parabola_min(alphas, C, ia);

% 3. Steps again at that skew, and which grooves continue into which
reg.cost = zeros(1, nP);
reg.match = cell(1, nP);
reg.offset = zeros(1, nP);
for k = 1:nP
    [reg.step(k), reg.cost(k), reg.match{k}, reg.offset(k)] = best_step( ...
        tracks{pairs(k,1)}, tracks{pairs(k,2)}, cam, Rcam, reg.alpha, ...
        reg.step(k), off0(k), setfield(opts, 'searchPx', 2));
end
% 4. A full ring must add up to exactly one revolution; spreading the
%    small leftover over all steps removes any systematic sub-pixel bias
if opts.ring
    reg.step = reg.step * (2*pi / sum(reg.step));
end
reg.pairs = pairs;
end

function [stepBest, costBest, match, offset] = best_step(tA, tB, cam, Rcam, alpha, step0, off0, opts)
% Search the rotation step that best overlays frame B's grooves on A's
[thA, rA] = centre_polar(tA, cam, Rcam, alpha);
[thB, rB] = centre_polar(tB, cam, Rcam, alpha);
pixAng = cam.pixel / Rcam;
if isnan(opts.searchPx)
    steps = step0 * (1 - opts.search) : pixAng : step0 * (1 + opts.search);
else
    steps = step0 + (-opts.searchPx : opts.searchPx) * pixAng;
end
cost = inf(size(steps));
for s = 1:numel(steps)
    cost(s) = overlap_cost(thA, rA, thB + steps(s), rB, opts.pitch, off0);
end
[~, is] = min(cost);
% refine at sub-pixel spacing around the best
fine = steps(is) + (-1:0.1:1) * pixAng;
costF = arrayfun(@(st) overlap_cost(thA, rA, thB + st, rB, opts.pitch, off0), fine);
[costBest, i2] = min(costF);
stepBest = parabola_min(fine, costF, i2);
[costBest, match, offset] = overlap_cost(thA, rA, thB + stepBest, rB, opts.pitch, off0);
end

function a = groove_slope(tracks)
% Skew from the slope of the groove centres across the images: a groove
% of constant radius runs at rows/columns = tan(alpha) near the centre
sl = [];
for k = 1:numel(tracks)
    c = (tracks{k}.outer + tracks{k}.inner) / 2;
    W = size(c, 2);
    for i = 1:size(c, 1)
        ok = ~isnan(c(i, :));
        if nnz(ok) < 0.5 * W, continue; end
        q = polyfit(find(ok), c(i, ok), 1);
        sl(end+1) = q(1);   %#ok<AGROW>
    end
end
if isempty(sl), a = 0; else, a = atan(median(sl)); end
end

function [th, r] = centre_polar(t, cam, Rcam, alpha)
% Groove centre lines of one frame in rig polar coordinates
W = size(t.outer, 2);
cols = repmat(1:W, size(t.outer, 1), 1);
[th, r] = frame_to_polar((t.outer + t.inner)/2, cols, cam, Rcam, alpha);
end

function [c, match, offset] = overlap_cost(thA, rA, thB, rB, pitch, off0)
% How badly the groove wiggles disagree where the frames overlap, after
% removing their common radial offset (which a camera skew causes); also
% the groove correspondence (match(i) = groove of B continuing groove i
% of A, searched around the expected shift off0) and that common offset (um)
lo = max(min(thA(:)), min(thB(:)));
hi = min(max(thA(:)), max(thB(:)));
match = zeros(size(rA, 1), 1);
offset = NaN;
if hi <= lo
    c = inf;
    return;
end
grid = linspace(lo, hi, 64);
RA = resample_rows(thA, rA, grid);
RB = resample_rows(thB, rB, grid);
diffs = [];
for i = 1:size(RA, 1)
    if all(isnan(RA(i, :))), continue; end
    D = median_omitnan(abs(RB - off0 - RA(i, :)), 2);
    [m, j] = min(D);
    if m < pitch / 3
        match(i) = j;
        diffs(end+1, :) = RB(j, :) - RA(i, :);   %#ok<AGROW>
    end
end
if size(diffs, 1) < 2
    c = inf;
    return;
end
offset = median(diffs(~isnan(diffs)));
dev = abs(diffs - offset);
c = median(dev(~isnan(dev))) + pitch * (1 - size(diffs, 1)/size(RA, 1)) * 0.01;
end

function R = resample_rows(th, r, grid)
R = nan(size(r, 1), numel(grid));
for i = 1:size(r, 1)
    ok = ~isnan(r(i, :)) & ~isnan(th(i, :));
    if nnz(ok) < 2, continue; end
    [t, k] = sort(th(i, ok));
    rr = r(i, ok);  rr = rr(k);
    [t, u] = unique(t);
    R(i, :) = interp1(t, rr(u), grid, 'linear', NaN);
end
end

function xm = parabola_min(x, y, i)
% Vertex of the parabola through the minimum and its neighbours
if i == 1 || i == numel(x) || any(~isfinite(y(i-1:i+1)))
    xm = x(i);
    return;
end
den = y(i-1) - 2*y(i) + y(i+1);
if den <= 0
    xm = x(i);
    return;
end
xm = x(i) + 0.5 * (y(i-1) - y(i+1)) / den * (x(i+1) - x(i));
end
