function mt = motion_trace(scan, S, vs)
%MOTION_TRACE  Disc rotation per frame from the motion trace + loop closure.
%   mt = MOTION_TRACE(scan, S, vs). The content shift between consecutive
%   frames (along the groove) is integrated to U_k (full-res px). The frame
%   where frame 1's content comes back gives the revolution length L in px
%   (method A3), so theta0_k = 2*pi*(U_k - U_1)/|L| and the axis is
%   R0 = |L|/(2 pi) px from the image centre. theta increases when the
%   content moves towards +x.
%   vs: open frame source, for reading frames 1 and k* at full resolution.
K = scan.K; ds = scan.ds; W = scan.W;
du = scan.du; dv = scan.dv; pk = scan.pk;
du(1) = 0; dv(1) = 0; pk(1) = 1;
% weak matches: replace by the neighbours' motion
bad = pk < 0.02 | isnan(du);
if any(bad(2:end))
    good = find(~bad);
    du(bad) = interp1(good, du(good), find(bad), 'linear', 'extrap');
    dv(bad) = interp1(good, dv(good), find(bad), 'linear', 'extrap');
end
U = cumsum(du); V = cumsum(dv);
fprintf('motion: %d frames, |du| median %.1f px/frame (max %.1f), %d weak matches interpolated\n', ...
    K, median(abs(du(2:end))), max(abs(du)), nnz(bad(2:end)));
fprintf('motion: total travel %.0f px along the groove, %.0f px across\n', U(end) - U(1), V(end) - V(1));

% --- loop closure: where does frame 1 come back? (thumbnails, 1/(4 ds))
T = scan.thumb;
far = abs(U - U(1)) > 2 * W;
cand = find(far);
if isempty(cand)
    error('motion_trace:noLoop', 'the video does not travel far enough for a loop closure');
end
q = zeros(numel(cand), 1); sx = q; sy = q;
T1 = T(:, :, 1);
for i = 1:numel(cand)
    [sx(i), sy(i), q(i)] = phase_corr(T1, T(:, :, cand(i)));
end
[qbest, ib] = max(q);
base = median(q);
kStar = cand(ib);
fprintf('loop closure: frame 1 best matches frame %d, peak %.3f (unrelated frames median %.3f, ratio %.1f; need >= %.2f and 5x)\n', ...
    kStar, qbest, base, qbest / base, S.overlap.minMatch);
if qbest < S.overlap.minMatch || qbest < 5 * base
    error('motion_trace:loopClosure', 'no reliable loop closure (peak %.3f, unrelated %.3f)', qbest, base);
end
% refine at full resolution
mir = S.microscope.mirrored;
[G1, vs] = vsrc_frame(vs, 1, mir, scan.thumb(:, :, 1), ds);
[Gk, vs] = vsrc_frame(vs, kStar, mir, scan.thumb(:, :, kStar), ds); %#ok<ASGLU>
[ddx, ddy, qq] = phase_corr(G1, Gk);
L = (U(kStar) - U(1)) - ddx;
fprintf('loop closure (full res): frame 1 content sits at (%+.2f, %+.2f) px in frame %d, peak %.3f\n', ddx, ddy, kStar, qq);
R0 = abs(L) / (2 * pi);

% --- all closure pairs over the overlap (thumbnails), for the spread of L
th0 = 2 * pi * (U - U(1)) / abs(L);
dirn = sign(L);
pairs = zeros(0, 2);
for k = 1:K
    [dmin, k2] = min(abs(th0 - th0(k) - dirn * 2 * pi));
    if dmin < 0.5 * W / R0 && k2 > k
        pairs(end+1, :) = [k, k2]; %#ok<AGROW>
    end
end
pairs = pairs(1:max(1, round(size(pairs, 1) / 60)):end, :);
Lp = nan(size(pairs, 1), 1); qp = Lp; dyp = Lp;
for i = 1:size(pairs, 1)
    [a, c, qp(i)] = phase_corr(T(:, :, pairs(i, 1)), T(:, :, pairs(i, 2)));
    Lp(i) = (U(pairs(i, 2)) - U(pairs(i, 1))) - a * 4 * ds;
    dyp(i) = c * 4 * ds;
end
okp = qp > 0.5 * qbest;
fprintf('loop closure over the overlap: %d pairs (%d good); revolution length %.0f px, spread (std) %.1f px = %.3f%%\n', ...
    numel(Lp), nnz(okp), L, std(Lp(okp)), 100 * std(Lp(okp)) / abs(L));

mt.U = U; mt.V = V; mt.du = du; mt.dv = dv; mt.weak = bad;
mt.L = L; mt.R0 = R0; mt.theta0 = th0; mt.kStar = kStar;
mt.closure = struct('peak', qbest, 'base', base, 'dx', ddx, 'dy', ddy, 'peakFull', qq);
mt.pairs = pairs; mt.pairL = Lp; mt.pairPeak = qp; mt.pairDy = dyp;
fprintf('motion: R0 = %.0f px = %.2f mm (axis to image centre), %.3f revolutions in the video\n', ...
    R0, R0 * S.microscope.pixelAt1x_um / S.microscope.magnification / 1000, abs(th0(end)) / (2 * pi));
end
