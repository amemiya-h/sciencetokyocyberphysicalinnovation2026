function T = groove_tracks(I, Pp, colPx, slope, wpx, tol)
%GROOVE_TRACKS  Grooves of one frame as tracks, and their centres per column.
%   T = GROOVE_TRACKS(I, Pp, colPx, slope, wpx, tol). I: h x nC image
%   columns (one image column, or the mean of a block of colPx columns),
%   Pp: normal groove spacing (rows), slope: groove direction (rows per
%   image px), wpx: nominal groove width (rows), tol: width tolerance.
%   Detection (on a cleaned copy):
%     1. lighting flattened (divided by a blur ~3 spacings wide);
%     2. a grey closing along the groove direction, ~1.5 spacings long,
%        fills in dark features shorter than that along the groove
%        (scratches across the lands, specks);
%     3. dark = below the midpoint of the local light and dark levels;
%        runs much taller than a groove (> 1.3 (1+tol) wpx: a groove merged
%        with dust) are cut out so they cannot join two grooves;
%     4. connected dark regions are tracks; a track spanning >= 25% of the
%        columns is (part of) a groove, shorter ones are dust or specks on
%        land; pieces of one groove split by dust are joined when they lie
%        at the same height (straightened along the groove, within 0.4 Pp).
%   Measurement (on the original, only flattened, pixels): in each column,
%   the dark run(s) at a groove give its two half-level edges; centre =
%   midpoint, width = distance. Runs much wider than a groove (dust on
%   it) keep their groove but get ok = false (no position).
%   T.col, T.y (rows, sub-pixel), T.w (rows), T.amp (local contrast),
%   T.g (groove index in this frame, 1 = top), T.ok; T.nG grooves.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end
[h, nC] = size(I);
I = double(I);
% 1. flatten
s = 3 * Pp; sc = max(1, s / colPx);
gy = exp(-(-ceil(2 * s):ceil(2 * s)).^2 / (2 * s^2)); gy = gy / sum(gy);
gx = exp(-(-ceil(2 * sc):ceil(2 * sc)).^2 / (2 * sc^2)); gx = gx / sum(gx);
Bl = conv2(gy, gx, I, 'same') ./ conv2(gy, gx, ones(h, nC), 'same');
Gn = I ./ max(Bl, 1e-3);
% 2. closing along the groove direction
L = 2 * round(0.75 * Pp / colPx) + 1;
sh = round(slope * colPx * ((1:nC) - (nC + 1) / 2));
Gc = shearc(movmin(movmax(shearc(Gn, -sh), L, 2), L, 2), sh);
% 3. dark/light on the cleaned image, tall runs cut out
win = 2 * round(Pp) + 1;
hi = movmax(Gc, win, 1); lo = movmin(Gc, win, 1);
dk = Gc < (hi + lo) / 2 & (hi - lo) > 0.15 * median(hi(:));
maxRun = 1.3 * (1 + tol) * wpx;
d = diff([false(1, nC); dk; false(1, nC)], 1, 1);
[rs, cs] = find(d == 1);
[re, ~] = find(d == -1); re = re - 1;
tall = (re - rs + 1) > maxRun;
for i = find(tall)'
    dk(rs(i):re(i), cs(i)) = false;
end
% 4. tracks
[lab, nl] = bwlabel(dk, 4);
if nl == 0, T = empty(); return; end
[rr, cc] = find(lab); li = lab(lab > 0);
uc = unique([li, cc], 'rows');
ncol = accumarray(uc(:, 1), 1, [nl, 1]);
ys = rr - slope * colPx * (cc - (nC + 1) / 2);         % straightened height
ymed = accumarray(li, ys, [nl, 1], @median);
long = ncol >= 0.25 * nC;
lid = find(long);
[ysrt, o] = sort(ymed(lid)); lid = lid(o);
grp = cumsum([1; diff(ysrt) > 0.4 * Pp]);
map = zeros(nl, 1); map(lid) = grp;
nG = max([0; grp]);
% measurement on the original (flattened) pixels
hiO = movmax(Gn, win, 1); loO = movmin(Gn, win, 1); mid = (hiO + loO) / 2;
dO = Gn < mid;
dd = diff([false(1, nC); dO; false(1, nC)], 1, 1);
[s0, c0] = find(dd == 1); [e0, ~] = find(dd == -1); e0 = e0 - 1;
keep = s0 > 1 & e0 < h;
s0 = s0(keep); e0 = e0(keep); c0 = c0(keep);
% sub-pixel half-level crossings
Sg = Gn - mid;
i1 = sub2ind([h, nC], s0 - 1, c0); f1 = frac(Sg(i1), Sg(i1 + 1));
i2 = sub2ind([h, nC], e0, c0); f2 = frac(Sg(i2), Sg(i2 + 1));
ya = s0 - 1 + f1; yb = e0 + f2;
% which groove each original run belongs to: the track under its centre,
% or the nearest track pixel within a quarter spacing
yc = (ya + yb) / 2;
g = zeros(size(yc));
for off = [0, -1, 1, -2, 2, -4, 4, -round(Pp / 4), round(Pp / 4)]
    r = min(h, max(1, round(yc) + off));
    lb = lab(sub2ind([h, nC], r, c0));
    nw = g == 0 & lb > 0;
    g(nw) = map(lb(nw));
end
in = g > 0;
ya = ya(in); yb = yb(in); c0 = c0(in); g = g(in);
% one reading per groove and column (a bottom line can split a run)
key = (c0 - 1) * (nG + 1) + g;
[uk, ~, j] = unique(key);
A = accumarray(j, ya, [], @min); Bv = accumarray(j, yb, [], @max);
T.col = floor((uk - 1) / (nG + 1)) + 1;
T.g = uk - (T.col - 1) * (nG + 1);
T.y = (A + Bv) / 2; T.w = Bv - A;
T.amp = (hiO(sub2ind([h, nC], min(h, max(1, round(T.y))), T.col)) - loO(sub2ind([h, nC], min(h, max(1, round(T.y))), T.col)));
T.ok = abs(T.w / wpx - 1) <= tol;
T.nG = nG;
end

function T = empty()
T = struct('col', [], 'g', [], 'y', [], 'w', [], 'amp', [], 'ok', [], 'nG', 0);
end

function Y = shearc(X, sh)
[h, w] = size(X);
r = min(h, max(1, (1:h)' - sh(:)'));
Y = X(r + (0:w-1) * h);
end

function f = frac(a, b)
f = 0.5 * ones(size(a));
m = sign(a) ~= sign(b) & a ~= b;
f(m) = a(m) ./ (a(m) - b(m));
f = max(0, min(1, f));
end
