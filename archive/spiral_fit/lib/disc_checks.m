function ck = disc_checks(M, chunks, mt, scan, S, R, vs, info, Lk)
%DISC_CHECKS  The Part A checks of method A6, printed and plotted.
%   0. lock margin of the chain, overlaps (turn counts) and motion-link
%      residuals after the fit;
%   1. residual phase vs the music: median |Psi - n| in um, split into a
%      within-groove (fast, music-like) part and a per-groove offset/slope
%      (slow, model error + low notes) part, and a per-frame bias;
%   2. spiral centre path in the image: a smooth circle (fixed rig);
%   3. P(r): smooth, near the nominal pitch, no jumps;
%   4. loop closure: the same disc point one revolution later, at full
%      resolution: radial and along-groove mismatch (a slipped turn would
%      show as a radial mismatch of one pitch).
% Figure: R.dir/partA_checks.png.
p = M.p; K = M.K;
fprintf('\n---- Part A checks ----\n');
fprintf('spiral sense s = %+d, pixel %.4f um, %d frames\n', M.s, p, K);

% 1. residual phase
Rr = disc_residuals(M, chunks, 2);
ru = double(Rr.rho) .* double(Rr.P);
x = double(Rr.x); k = double(Rr.k);
gid = double(Rr.n);
[~, ~, grp] = unique(k * 1e5 + (gid - min(gid)));
n = accumarray(grp, 1); sx = accumarray(grp, x); sxx = accumarray(grp, x.^2);
sr = accumarray(grp, ru); sxr = accumarray(grp, x .* ru);
det = n .* sxx - sx.^2;
okg = n >= 6 & det > 0;
b1 = zeros(size(n)); b0 = sr ./ n;
b1(okg) = (n(okg) .* sxr(okg) - sx(okg) .* sr(okg)) ./ det(okg);
b0(okg) = (sr(okg) - b1(okg) .* sx(okg)) ./ n(okg);
slow = b0(grp) + b1(grp) .* x;
fast = ru - slow;
use = okg(grp);
rr = @(v) 1.4826 * median(abs(v - median(v)));
fb = accumarray(k, ru, [K, 1], @median, NaN);
ck.medAbs_um = median(abs(ru));
ck.rms_um = rr(ru);
ck.fast_um = rr(fast(use));
ck.slow_um = rr(slow(use));
ck.frameBiasRms_um = sqrt(mean(fb(~isnan(fb)).^2));
ck.frameBiasMax_um = max(abs(fb));
ck.nReadings = numel(ru) * 2;
fprintf('[1] phase residual: median |wrap(Psi)| = %.2f um, robust rms %.2f um (%.3f pitch)\n', ...
    ck.medAbs_um, ck.rms_um, ck.rms_um / median(double(Rr.P)));
fprintf('    within-groove (music + reading noise): rms %.2f um\n', ck.fast_um);
fprintf('    per-groove offset+slope (model error + low notes): rms %.2f um\n', ck.slow_um);
fprintf('    per-frame bias: rms %.2f um, max %.2f um\n', ck.frameBiasRms_um, ck.frameBiasMax_um);
fprintf('    -> expect the residual about the music rms, not larger: residual/within-groove = %.2f\n', ck.rms_um / ck.fast_um);
rho = double(Rr.rho);
ck.rhoOver25 = mean(abs(rho) > 0.25); ck.rhoOver50 = mean(abs(rho) > 0.5);
fprintf('    readings with |Psi - n| > 1/4 turn: %.2f%%, > 1/2 turn: %.2f%% (turn numbers from the chain and the grooves counted in each frame)\n', 100 * ck.rhoOver25, 100 * ck.rhoOver50);
% lane count: neighbouring grooves in one column must be exactly one turn apart
yv = double(Rr.y); ps = double(Rr.psi);
dyl = diff(yv); spl = double(Rr.P(1:end-1)) / M.p;
lp = find(diff(k) == 0 & diff(x) == 0 & dyl > 0.6 * spl & dyl < 1.5 * spl);
dl = ps(lp + 1) - ps(lp) - M.sgnY;
ck.laneSlips = nnz(abs(dl) > 0.5); ck.lanePairs = numel(lp);
ck.laneRms_um = 1.4826 * median(abs(dl)) * median(double(Rr.P));
fprintf('    lane count: %d of %d neighbouring-groove pairs not exactly one turn apart (spread %.2f um)\n', ...
    ck.laneSlips, ck.lanePairs, ck.laneRms_um);

% 2. centre path
c = M.c;
A = [c, ones(K, 1)];
sol = A \ (-(c(:, 1).^2 + c(:, 2).^2));
ctr = -sol(1:2)' / 2;
rad = sqrt(max(0, sum(ctr.^2) - sol(3)));
dev = hypot(c(:, 1) - ctr(1), c(:, 2) - ctr(2)) - rad;
d2 = diff(c, 2, 1);
ah = M.a / norm(M.a); tg = [ah(2); -ah(1)];
stepRad = diff(c) * ah / (median(double(Rr.P)) / p);     % radial centre step, grooves
ck.circleCentre_px = ctr; ck.circleRadius_um = rad * p;
ck.circleRms_um = sqrt(mean(dev.^2)) * p; ck.circleMax_um = max(abs(dev)) * p;
ck.pathAccelRms_px = sqrt(mean(sum(d2.^2, 2)));
ck.axis_px = M.a'; ck.stepRadialMax_groove = max(abs(stepRad));
ck.R_mm = norm(M.a) * p / 1000; ck.R0_mm = M.R0 * p / 1000;
ck.skew_deg = atan2d(-M.a(1), M.a(2) * M.sgnY);
fprintf('[2] spiral centre path c_k (free per frame): mean at %.3f mm from the image centre (revolution length gives %.3f mm), skew %.2f deg\n', ...
    ck.R_mm, ck.R0_mm, ck.skew_deg);
fprintf('    best circle through the path: radius %.1f um, deviation rms %.2f um, max %.2f um (a fixed-axis rig: circle + shake)\n', ...
    ck.circleRadius_um, ck.circleRms_um, ck.circleMax_um);
fprintf('    radial centre step per frame: max %.3f groove, rms %.3f; smoothness: rms 2nd difference %.3f px/frame^2\n', ...
    ck.stepRadialMax_groove, sqrt(mean(stepRad.^2)), ck.pathAccelRms_px);
ck.thetaChangeMax_px = max(abs(M.Wk * M.dth)) * M.R0;
fprintf('    theta change from the fit: max %.2f px along the groove\n', ck.thetaChangeMax_px);

% 0. lock margin, overlaps, motion links
Ch = info.chain;
mg = Ch.margin(2:end);
ck.lockMarginMin = min(mg); ck.lockMarginMedian = median(mg);
ck.lockFlagged = numel(Ch.flag); ck.lockFlaggedFrames = Ch.flag(:)';
ck.chainLinkErrMax = max(abs(Ch.linkErr(2:end)));
ck.linkSign = Ch.sign;
fprintf('[0] lock margin per chain step: min %.3f, median %.3f turns; %d steps below %.2f%s; link error max %.3f turns; link sign %+d\n', ...
    ck.lockMarginMin, ck.lockMarginMedian, ck.lockFlagged, S.spiralFit.lockMarginMin_turns, ...
    iff_(ck.lockFlagged > 0, sprintf(' (frames %s)', mat2str(Ch.flag(1:min(12, end))')), ''), ck.chainLinkErrMax, ck.linkSign);
[~, Il] = disc_pack(M);
[~, ~, ~, rl] = disc_links(M, Lk, S.spiralFit.huberK, Il);
gpx = M.p / median(double(Rr.P));                      % turns per px
mo = Lk.kind == 1; ov = Lk.kind == 2;
ck.linkAlongRms_px = sqrt(mean(rl(mo, 1).^2)); ck.linkAcrossRms_px = sqrt(mean(rl(mo, 2).^2));
ck.linkAcrossMax_groove = max(abs(rl(mo, 2))) * gpx;
ck.linkAlongNorm = sqrt(mean((rl(mo, 1) ./ Lk.sig(mo, 1)).^2)); ck.linkAcrossNorm = sqrt(mean((rl(mo, 2) ./ Lk.sig(mo, 2)).^2));
fprintf('    motion links (%d): residual along the groove rms %.2f px (%.2f sigma), across rms %.2f px = %.3f groove (%.2f sigma), max across %.3f groove\n', ...
    nnz(mo), ck.linkAlongRms_px, ck.linkAlongNorm, ck.linkAcrossRms_px, ck.linkAcrossRms_px * gpx, ck.linkAcrossNorm, ck.linkAcrossMax_groove);
zl = max(abs(rl ./ Lk.sig), [], 2);
[~, io] = sort(zl, 'descend'); io = io(1:min(5, end));
fprintf('    worst links (a->b, kind, residual along/across px, sigma): ');
fprintf('%d->%d k%d (%+.1f, %+.1f, %.1f) ', [Lk.a(io)'; Lk.b(io)'; Lk.kind(io)'; rl(io, 1)'; rl(io, 2)'; zl(io)']);
fprintf('\n');
if any(ov)
    eo = rl(ov, :);
    erad = (eo * ah) * gpx; eal = eo * tg;
    ck.overlapTurnDisagree = nnz(abs(erad) >= 0.5);
    ck.overlapRadialMedAbs_um = median(abs(erad)) * median(double(Rr.P));
    ck.overlapRadialMaxAbs_um = max(abs(erad)) * median(double(Rr.P));
    ck.overlapAlongMedAbs_um = median(abs(eal)) * p;
    fprintf('    overlaps (%d pairs one revolution apart, match >= %.2f): turn disagreements with the chain: %d (must be 0); radial residual median %.2f um, max %.2f um (turn = %.0f um); along the groove median %.2f um\n', ...
        nnz(ov), S.overlap.minMatch, ck.overlapTurnDisagree, ck.overlapRadialMedAbs_um, ck.overlapRadialMaxAbs_um, median(double(Rr.P)), ck.overlapAlongMedAbs_um);
else
    ck.overlapTurnDisagree = NaN;
    fprintf('    overlaps: none accepted\n');
end

% 3. pitch
rq = double(prctile_(double(Rr.r), [1, 99]));
rg = linspace(rq(1), rq(2), 400)';
Pg = 1 ./ (b3((rg - M.rC') / M.rh) * M.beta);
turnsSpan = (rq(2) - rq(1)) / median(Pg);
dP = diff(Pg) ./ diff(rg) .* Pg(1:end-1);  % change per turn
ck.P_min = min(Pg); ck.P_max = max(Pg); ck.P_mean = mean(Pg);
ck.P_maxChangePerTurn = max(abs(dP));
ck.r_range_mm = rq / 1000;
fprintf('[3] pitch P(r) over r = %.3f..%.3f mm (%.1f turns): mean %.2f um, range %.2f..%.2f um, max change %.3f um/turn\n', ...
    rq(1) / 1000, rq(2) / 1000, turnsSpan, ck.P_mean, ck.P_min, ck.P_max, ck.P_maxChangePerTurn);
if ck.P_min < S.record.pitchMin_um || ck.P_max > S.record.pitchMax_um
    fprintf('    WARNING: pitch outside [%g, %g] um\n', S.record.pitchMin_um, S.record.pitchMax_um);
end
kc = histcounts_(double(Rr.r), M.rC(1):M.rh:M.rC(end) + M.rh / 2);
fprintf('    pitch knots (r mm: P um, readings in the knot interval): ');
for i = 1:numel(M.rC), if i <= numel(kc), nn = kc(i); else, nn = 0; end; fprintf('%.2f:%.0f(%d) ', M.rC(i) / 1000, 1 / M.beta(i), nn); end
fprintf('\n');
xs = linspace(-M.xs, M.xs, 65); ys = linspace(-M.ys, M.ys, 49);
[XX, YY] = meshgrid(xs, ys);
DD = disc_distortion(M, XX, YY);
ck.distortionPP_px = max(DD(:)) - min(DD(:));
fprintf('    lens distortion across the grooves: %.2f px peak to peak\n', ck.distortionPP_px);

% 4. loop closure at full resolution
good = find(mt.pairPeak > 0.5 * mt.closure.peak);
sel = good(unique(round(linspace(1, numel(good), min(12, numel(good))))));
mir = S.microscope.mirrored;
lc = nan(numel(sel), 6);
for i = 1:numel(sel)
    k1 = mt.pairs(sel(i), 1); k2 = mt.pairs(sel(i), 2);
    [G1, vs] = vsrc_frame(vs, k1, mir, scan.thumb(:, :, k1), scan.ds);
    [G2, vs] = vsrc_frame(vs, k2, mir, scan.thumb(:, :, k2), scan.ds);
    [dx, dy, q] = phase_corr(G1, G2);
    q1 = [-dx / 2; -dy / 2];                         % middle of the overlap, frame k1
    X = disc_from_image(M, k1, q1(1), q1(2));
    [x2, y2] = disc_to_image(M, k2, X);
    X2 = disc_from_image(M, k2, q1(1) + dx, q1(2) + dy);  % where it was seen
    rad1 = norm(X); rad2 = norm(X2);
    tang = (atan2(X2(2), X2(1)) - atan2(X(2), X(1)));
    tang = mod(tang + pi, 2 * pi) - pi;
    lc(i, :) = [k1, k2, rad2 - rad1, tang * rad1, q, hypot(q1(1) + dx - x2, q1(2) + dy - y2)];
end
ck.loop = lc;
Pm = ck.P_mean;
fprintf('[4] loop closure, %d frame pairs one revolution apart (full resolution):\n', size(lc, 1));
fprintf('     frame -> frame   radial mismatch    along-groove   match\n');
for i = 1:size(lc, 1)
    fprintf('    %5d -> %5d   %+7.2f um (%+.3f P)   %+8.2f um   %.3f\n', lc(i, 1), lc(i, 2), lc(i, 3), lc(i, 3) / Pm, lc(i, 4), lc(i, 5));
end
ck.loopRadialMedAbs_um = median(abs(lc(:, 3)));
ck.loopRadialMaxAbs_um = max(abs(lc(:, 3)));
ck.loopAlongMedAbs_um = median(abs(lc(:, 4)));
fprintf('    radial: median |.| %.2f um, max %.2f um (one turn would be %.0f um)\n', ...
    ck.loopRadialMedAbs_um, ck.loopRadialMaxAbs_um, Pm);

% figure
fig = figure('Visible', 'off', 'Position', [50 50 1500 900]);
subplot(2, 3, 1);
plot(c(:, 1) * p / 1000, c(:, 2) * p / 1000, '.-', 'MarkerSize', 3); hold on;
tt = linspace(0, 2 * pi, 200);
plot((ctr(1) + rad * cos(tt)) * p / 1000, (ctr(2) + rad * sin(tt)) * p / 1000, 'r:');
plot(M.a(1) * p / 1000, M.a(2) * p / 1000, 'k+');
plot(M.c0(:, 1) * p / 1000, M.c0(:, 2) * p / 1000, ':', 'Color', [0.6 0.6 0.6]);
axis equal; set(gca, 'YDir', 'reverse'); grid on;
xlabel('x (mm, image axes)'); ylabel('y (mm)');
title(sprintf('centre path c_k (grey: chain start), off-circle rms %.1f um', ck.circleRms_um));
subplot(2, 3, 2);
plot(rg / 1000, Pg); grid on; xlabel('r (mm)'); ylabel('P (um)');
title(sprintf('pitch P(r): %.1f..%.1f um', ck.P_min, ck.P_max));
subplot(2, 3, 3);
edges = linspace(-0.5, 0.5, 101) * median(Pg);
histc_ = histcounts_(ru, edges);
bar((edges(1:end-1) + edges(2:end)) / 2, histc_, 1); grid on;
xlabel('wrap(\Psi) \times P (um)'); ylabel('readings');
title(sprintf('residual: median |.| %.2f um, music-like %.2f um', ck.medAbs_um, ck.fast_um));
subplot(2, 3, 4);
yyaxis left; plot(1:K, fb); ylabel('per-frame phase bias (um)');
yyaxis right; plot(1:K, Ch.margin, '.'); hold on; yline(S.spiralFit.lockMarginMin_turns, 'r:'); ylabel('lock margin (turns)');
grid on; xlabel('frame');
title(sprintf('chain: min margin %.2f, %d flagged', ck.lockMarginMin, ck.lockFlagged));
subplot(2, 3, 5);
imagesc(xs + (M.W + 1) / 2, ys + (M.H + 1) / 2, DD); axis image; colorbar;
title(sprintf('lens distortion across grooves (px), %.2f p-p', ck.distortionPP_px));
subplot(2, 3, 6);
plot(lc(:, 1), lc(:, 3), 'o-', lc(:, 1), lc(:, 4), 's-'); grid on;
legend('radial', 'along groove'); xlabel('frame'); ylabel('mismatch (um)');
title(sprintf('loop closure (one turn = %.0f um)', Pm));
print(fig, fullfile(R.dir, 'partA_checks.png'), '-dpng', '-r110');
close(fig);
fprintf('figure: %s\n', fullfile(R.dir, 'partA_checks.png'));
end

function q = prctile_(v, pc)
v = sort(v(~isnan(v)));
q = v(max(1, min(numel(v), round(pc / 100 * numel(v)))));
end

function c = histcounts_(v, edges)
c = zeros(1, numel(edges) - 1);
i = discretize_(v, edges);
i = i(~isnan(i));
c = accumarray(i(:), 1, [numel(edges) - 1, 1])';
end

function i = discretize_(v, edges)
i = floor((v - edges(1)) / (edges(2) - edges(1))) + 1;
i(i < 1 | i > numel(edges) - 1) = NaN;
end

function v = iff_(c, a, b)
if c, v = a; else, v = b; end
end
