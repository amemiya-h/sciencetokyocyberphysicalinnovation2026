function reg = register_polar(G, nominalCols, opts)
%REGISTER_POLAR  Line up consecutive unwarped images using their grooves.
%   reg = REGISTER_POLAR(G, nominalCols, opts) takes the grooves read from
%   every unwarped image (read_grooves_polar) and, for each consecutive
%   pair (and last -> first for a ring), finds the shift along the groove
%   (columns, sub-pixel, starting from the motion trace's nominalCols)
%   at which the grooves' wiggles coincide best, the radial shift (rows),
%   and which groove continues which. The wiggles are compared after
%   removing each groove's slow part (moving mean over 31 columns): slow
%   bends differ between images (optics, wobble) and would otherwise
%   swamp the fine detail that pins the shift down.
%
%   opts fields (defaults in brackets)
%     pitchPx   groove spacing (px) [41]
%     searchPx  search +/- this many columns around nominalCols [3]
%     rows0     expected radial shift per pair (rows) [zeros]
%     ring      also pair the last image with the first [false]
%
%   Output struct reg
%     pairs   nP x 2 image numbers
%     shift   1 x nP shift along the groove (columns): a point at column j
%             of image b sits at column j + shift in image a
%     drow    1 x nP radial shift (rows) of image b's grooves relative to a
%     match   1 x nP cell, match{q}(i) = lane of b continuing lane i of a
%     cost    1 x nP median wiggle mismatch at the optimum (px)

if nargin < 3, opts = struct(); end
N = numel(G);
def = struct('pitchPx', 41, 'searchPx', 3, 'rows0', [], 'ring', false);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end
pairs = [(1:N-1)', (2:N)'];
if opts.ring, pairs(end+1, :) = [N, 1]; end
nP = size(pairs, 1);
rows0 = opts.rows0;
if isempty(rows0), rows0 = zeros(1, nP); end
for k = 1:N
    G{k}.hp = double(G{k}.c) - movmean_nan(double(G{k}.c), 31);
end
reg.pairs = pairs;
[reg.shift, reg.drow, reg.cost] = deal(nan(1, nP));
reg.match = cell(1, nP);
for q = 1:nP
    A = G{pairs(q, 1)};  B = G{pairs(q, 2)};
    s0 = nominalCols(q);
    cand = s0 + (-opts.searchPx : 0.5 : opts.searchPx);
    cost = inf(size(cand));
    for k = 1:numel(cand)
        cost(k) = pair_cost(A, B, cand(k), rows0(q), opts.pitchPx);
    end
    [~, k] = min(cost);
    fine = cand(k) + (-0.5:0.1:0.5);
    cf = arrayfun(@(s) pair_cost(A, B, s, rows0(q), opts.pitchPx), fine);
    [~, k2] = min(cf);
    sBest = parabola(fine, cf, k2);
    [reg.cost(q), reg.match{q}, reg.drow(q)] = pair_cost(A, B, sBest, rows0(q), opts.pitchPx);
    reg.shift(q) = sBest;
end
end

function [c, match, drow] = pair_cost(A, B, s, row0, pitchPx)
% B's column j is A's column j + s; compare the lanes in the overlap
W = size(A.c, 2);
ja = max(1, ceil(1 + s)) : min(W, floor(W + s));        % A columns seen by B
match = zeros(numel(A.row0), 1);
drow = NaN;
if numel(ja) < 32, c = inf; return; end
jb = ja - s;
nB = numel(B.row0);
CB = zeros(nB, numel(ja));  HB = CB;
for i = 1:nB
    CB(i, :) = interp_lin(double(B.c(i, :)), jb);
    HB(i, :) = interp_lin(B.hp(i, :), jb);
end
D = [];  E = [];
for i = 1:numel(A.row0)
    a = A.c(i, ja);
    [dmin, j] = min(abs(B.row0 - row0 - A.row0(i)));
    if dmin > pitchPx / 3, continue; end
    d = CB(j, :) - double(a);
    e = HB(j, :) - A.hp(i, ja);                 % fine wiggle only
    if nnz(~isnan(e)) < 16, continue; end
    match(i) = j;
    D(end+1, :) = d;   %#ok<AGROW>
    E(end+1, :) = e;   %#ok<AGROW>
end
if size(D, 1) < 2, c = inf; return; end
v = D(~isnan(D));
drow = median(v);
v = E(~isnan(E));
c = median(abs(v)) + 0.01 * pitchPx * (1 - size(D, 1) / numel(A.row0));
end

function m = movmean_nan(X, n)
% moving mean along rows, ignoring NaN
k = ones(1, n);
ok = ~isnan(X);  Z = X;  Z(~ok) = 0;
m = conv2(Z, k, 'same') ./ conv2(double(ok), k, 'same');
m(~ok) = NaN;
end

function y = interp_lin(v, x)
% linear interpolation of v (1..n) at x, NaN outside or next to NaN
n = numel(v);
i = floor(x);  t = x - i;
y = nan(size(x));
ok = i >= 1 & i < n;
y(ok) = (1 - t(ok)) .* v(i(ok)) + t(ok) .* v(i(ok) + 1);
e = i == n;  y(e) = v(n);
end

function xm = parabola(x, y, i)
if i == 1 || i == numel(x) || any(~isfinite(y(i-1:i+1))), xm = x(i); return; end
den = y(i-1) - 2*y(i) + y(i+1);
if den <= 0, xm = x(i); return; end
xm = x(i) + 0.5 * (y(i-1) - y(i+1)) / den * (x(i+1) - x(i));
end
