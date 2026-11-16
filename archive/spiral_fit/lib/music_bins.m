function B = music_bins(Rall, S)
%MUSIC_BINS  Combine all views into time bins (method B4).
%   B = MUSIC_BINS(Rall, S). Rall rows: [bin, x, xInner, xOuter, weight,
%   frame], one per frame and bin. Per bin, a robust weighted mean over the
%   views: each view's weight (its stripe contrast) times a Huber weight
%   (grooveReading.huberK) on its distance from the bin's median, so a
%   view that disagrees is down-weighted, not dropped. With
%   music.binAverage = 'mean' the Huber step is skipped.
%   Only bins no view covers are empty. B.views (views per bin), B.spread_um (robust spread between views),
%   B.binSpread (per bin). Bins without readings are NaN.
b = Rall(:, 1);
b0 = min(b); nb = max(b) - b0 + 1;
ib = b - b0 + 1;
views = accumarray(ib, 1, [nb, 1]);
w = Rall(:, 5);
med = grouped_median(ib, Rall(:, 2), nb);
dev = Rall(:, 2) - med(ib);
multi = views(ib) >= 2;
corr = sqrt(views(ib) ./ max(views(ib) - 1, 1));
sp = 1.4826 * median(abs(dev(multi)) .* corr(multi));
if strcmpi(S.music.binAverage, 'robust')
    hk = S.grooveReading.huberK;
    a = abs(dev) / max(sp, eps);
    w = w .* min(1, hk ./ max(a, eps));
end
sw = accumarray(ib, w, [nb, 1]);
X = nan(nb, 3);
for j = 1:3
    X(:, j) = accumarray(ib, w .* Rall(:, 1 + j), [nb, 1]) ./ sw;
end
X(views == 0 | sw <= 0, :) = NaN;
B.bin0 = b0; B.views = views; B.weight = sw;
B.x = X(:, 1); B.xIn = X(:, 2); B.xOut = X(:, 3);
B.t = (b0 + (0:nb-1)' + 0.5) / S.music.binRate_Hz;
B.spread_um = sp;
B.binSpread = sqrt(accumarray(ib(multi), dev(multi).^2, [nb, 1]) ./ max(accumarray(ib(multi), 1, [nb, 1]), 1));
B.binSpread(views < 2) = NaN;
end

function m = grouped_median(g, v, n)
[~, o] = sortrows([g, v]);
vs = v(o);
cnt = accumarray(g, 1, [n, 1]);
st = cumsum([1; cnt(1:end-1)]);
m = nan(n, 1);
h = cnt > 0;
lo = st(h) + floor((cnt(h) - 1) / 2);
hi = st(h) + ceil((cnt(h) - 1) / 2);
m(h) = (vs(lo) + vs(hi)) / 2;
end
