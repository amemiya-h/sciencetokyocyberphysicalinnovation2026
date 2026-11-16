function [R, st] = readings_to_bins(M, k, C, S)
%READINGS_TO_BINS  One Part B frame's groove centres -> music bins (B3).
%   [R, st] = READINGS_TO_BINS(M, k, C, S). C = [col y amp width groove ok]
%   (full-res pixels, from the scan's GROOVE_TRACKS) of frame k.
%   Turn numbers come from the grooves themselves: the frame's grooves are
%   numbered in order, n = n0 + (g - 1) (or minus, if Psi decreases down
%   the image), with n0 the value most well-fitting grooves (|Psi -
%   round(Psi)| < 0.2 at their median) agree on. So only grooves that exist
%   get turns, wherever the pitch does something the model cannot follow.
%   Through the disc model:
%     d = Psi - n,  x = -d P (um, outward +),  t = T (n - s phi / 2pi).
%   Where the model is off a groove by more than a quarter turn (the
%   spacing changes within a turn, e.g. between tracks), the groove's own
%   straight-line trend across the frame is its blank reference instead.
%   Weights: stripe contrast (min(1, (amp/median)^2)), 0 where the groove's
%   position is unusable (dust on it). The frame's small radial pose error
%   (a robust plane a + b x + c y) is removed; readings are then averaged
%   per time bin: R = [bin, x, xInner, xOuter, weight].
T = 60 / S.record.rpm;
C = double(C);
xc = C(:, 1) - (M.W + 1) / 2; yc = C(:, 2) - (M.H + 1) / 2;
g = C(:, 5); okp = C(:, 6) > 0;
E = disc_eval(M, xc, yc, k * ones(size(xc)));
% turn numbers by counting the frame's grooves
nG = max(g);
pm = accumarray(g, E.psi, [nG, 1], @median, NaN);
has = ~isnan(pm);
gi = find(has);
cand = round(pm(gi)) - M.sgnY * (gi - 1);
fr = pm(gi) - round(pm(gi));
good = abs(fr) < 0.2;
if any(good), n0 = mode(cand(good)); else, n0 = mode(cand); end
ng = n0 + M.sgnY * ((1:nG)' - 1);
n = ng(g);
d = E.psi - n; P = 1 ./ E.g;
renum = nnz(round(pm(gi)) ~= ng(gi));
% grooves the model misses by more than a quarter turn: own linear trend
off = false(size(d));
for q = gi'
    mm = g == q & okp;
    if nnz(mm) < 10, continue; end
    if abs(median(d(mm))) > 0.25
        A2 = [ones(nnz(mm), 1), xc(mm)];
        d(g == q) = d(g == q) - [ones(nnz(g == q), 1), xc(g == q)] * (A2 \ d(mm));
        off(g == q) = true;
    end
end
x = -d .* P;
amp = C(:, 3);
wt = min(1, (amp / median(amp(okp))).^2) .* okp;
x(~okp) = 0;
wu = C(:, 4) * M.p;
Ap = [ones(size(x)), xc / M.xs, yc / M.ys];
r = wt;
for it = 1:5
    pl = (Ap .* r) \ (x .* r);
    e = x - Ap * pl; sc = 1.4826 * median(abs(e(okp))) + 1e-9;
    r = wt .* min(1, 2 * sc ./ abs(e));
end
x = x - Ap * pl;
dw = (wu - median(wu(okp))) / 2;
t = T * (n - M.s * E.phi / (2 * pi));
if ~S.record.playsInward, t = -t; end
bin = floor(t * S.music.binRate_Hz);
[ub, ~, gb] = unique(bin);
sw = accumarray(gb, wt);
R = [ub, accumarray(gb, wt .* x) ./ sw, accumarray(gb, wt .* (x - dw)) ./ sw, ...
    accumarray(gb, wt .* (x + dw)) ./ sw, sw];
R = R(sw > 0, :);
st.n = numel(x); st.lowWeight = mean(wt < 0.25); st.plane = pl';
st.contrast = median(amp(okp)); st.width_um = median(wu(okp));
st.grooves = numel(gi); st.renumbered = renum; st.noPosition = mean(~okp); st.ownTrend = mean(off);
end
