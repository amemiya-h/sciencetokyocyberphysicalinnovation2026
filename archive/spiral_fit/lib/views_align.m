function [Rall, sh] = views_align(Rall, S, nIter, maxShift)
%VIEWS_ALIGN  Small along-groove pose correction per frame (methods A5, B3).
%   A frame's rotation error dtheta shifts the music time of all its
%   readings by the same T*dtheta/2pi. Each frame's binned readings are
%   compared with the mean of the OTHER views over a grid of time shifts
%   (+-maxShift bins, half-bin steps, then a parabolic refinement); the
%   frame is resampled by the best shift. Repeated nIter times. maxShift
%   is a few px along the groove, so a frame can never move by a turn.
%   Only the music above ~1 kHz-ish carries timing: each turn segment's
%   mean is removed before comparing.
%   Rall rows: [bin, x, xIn, xOut, count, frame]. sh: total shift per frame (bins).
fr = Rall(:, 6);
uf = unique(fr);
sh = zeros(numel(uf), 1);
grid = -maxShift:0.5:maxShift;
for it = 1:nIter
    b0 = min(Rall(:, 1)) - ceil(maxShift) - 2;
    nb = max(Rall(:, 1)) - b0 + ceil(maxShift) + 3;
    ib = Rall(:, 1) - b0;
    Csum = accumarray(ib, Rall(:, 2), [nb, 1]);
    Cn = accumarray(ib, 1, [nb, 1]);
    [~, ~, gf] = unique(Rall(:, 6));
    upd = zeros(numel(uf), 1);
    parfor j = 1:numel(uf)
        upd(j) = best_shift(Rall(gf == j, 1:2), b0, Csum, Cn, grid);
    end
    upd = upd - median(upd);                          % no common drift
    ur = sqrt(mean(upd.^2));
    if it > 1 && ur > 0.7 * prevR
        fprintf('  view alignment %d: update rms %.3f bins is not shrinking, stopping\n', it, ur);
        break;
    end
    prevR = ur;
    sh = sh + upd;
    for j = 1:numel(uf)
        if abs(upd(j)) < 1e-3, continue; end
        m = find(gf == j);
        Rall(m, :) = shift_frame(Rall(m, :), upd(j));
    end
    Rall = Rall(~isnan(Rall(:, 2)), :);
    fprintf('  view alignment %d: shift update rms %.3f bins, total rms %.3f bins (max %.2f)\n', ...
        it, sqrt(mean(upd.^2)), sqrt(mean(sh.^2)), max(abs(sh)));
end
end

function d = best_shift(R, b0, Csum, Cn, grid)
b = R(:, 1) - b0; x = R(:, 2);
seg = [true; diff(b) ~= 1]; sid = cumsum(seg);
ns = accumarray(sid, 1);
nbT = numel(Csum);
own = zeros(nbT, 1); own(b) = x;
ownN = zeros(nbT, 1); ownN(b) = 1;
O = (Csum - own) ./ (Cn - ownN);                     % mean of the other views
O(Cn - ownN < 1) = NaN;
e = nan(size(grid));
for g = 1:numel(grid)
    p = b + grid(g);
    q = floor(p); f = p - q;
    ok = q >= 1 & q < nbT;
    o = nan(size(p));
    o(ok) = (1 - f(ok)) .* O(q(ok)) + f(ok) .* O(q(ok) + 1);
    v = ~isnan(o);
    if nnz(v) < 0.3 * numel(x), continue; end
    om = accumarray(sid(v), o(v), size(ns)) ./ max(accumarray(sid(v), 1, size(ns)), 1);
    xm = accumarray(sid(v), x(v), size(ns)) ./ max(accumarray(sid(v), 1, size(ns)), 1);
    r = (x(v) - xm(sid(v))) - (o(v) - om(sid(v)));
    e(g) = mean(r.^2);
end
[em, i] = min(e);
if isnan(em), d = 0; return; end
d = grid(i);
if i > 1 && i < numel(grid) && ~isnan(e(i - 1)) && ~isnan(e(i + 1))
    den = e(i - 1) - 2 * em + e(i + 1);
    if den > 0, d = d + 0.5 * 0.5 * (e(i - 1) - e(i + 1)) / den; end
end
end

function m = subsasgn_mean(sid, x, ns)
mm = accumarray(sid, x) ./ ns;
m = mm(sid);
end

function R = shift_frame(R, d)
% x_k(b) = consensus(b + d): the reading at bin b belongs at b + d
b = R(:, 1); p = b + d;
seg = [true; diff(b) ~= 1]; sid = cumsum(seg);
for s = 1:sid(end)
    q = find(sid == s);
    if numel(q) < 2, R(q, 2:4) = NaN; continue; end
    nb = (ceil(p(q(1))):floor(p(q(end))))';
    k = min(numel(nb), numel(q));
    if k == 0, R(q, 2:4) = NaN; continue; end
    R(q(1:k), 1) = nb(1:k);
    R(q(1:k), 2:4) = interp1(p(q), R(q, 2:4), nb(1:k), 'linear');
    R(q(k+1:end), 2:4) = NaN;
end
end
