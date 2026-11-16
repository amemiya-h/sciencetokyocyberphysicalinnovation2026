function Lk = disc_link_set(M, mt, scan, S, Ppx)
%DISC_LINK_SET  Motion links and overlaps as shift measurements (method A3).
%   Each link joins frames a and b: the content of frame a appears in frame b
%   moved by m = (dx, dy) px, which the poses must reproduce:
%     m = c_b + Rot(theta_b - theta_a) (q - c_a) - q,  q = -m/2 (the middle of the overlap in frame a, where the
%   registration looked).
%   Motion links: every pair of consecutive frames (k-1, k), du and dv from
%   MOTION_TRACE, q = -m/2 (the registration compares the overlapping parts,
%   whose middle sits there), sigma motion.linkSigmaAlong_px along and
%   motion.linkSigmaAcross_groove x groove spacing across, grown by median(pk)/pk
%   where the match quality pk is below its median (weak matches: pk < 0.02).
%   Overlaps: frame pairs one revolution apart with a registration peak
%   >= overlap.minMatch, >= half the loop-closure peak, sigma overlap.sigma_px.
%   Lk.kind: 1 motion link, 2 overlap.
du = mt.du(:); dv = mt.dv(:);
pk = scan.pk(:); pk(1) = NaN;
pmed = median(pk(~isnan(pk)));
fac = max(1, pmed ./ max(pk, 0.02)); fac(isnan(fac)) = 1;
sa = S.motion.linkSigmaAlong_px * fac;
sc = S.motion.linkSigmaAcross_groove * Ppx * fac;
K = numel(du);
a = (1:K-1)'; b = (2:K)';
nl = K - 1;
m = [du(b), dv(b)];
sg = [sa(b), sc(b)];
Lk.a = a; Lk.b = b; Lk.m = m; Lk.q = -m / 2; Lk.sig = sg;
Lk.kind = ones(nl, 1);
% overlaps
pr = mt.pairs;
use = mt.pairPeak >= S.overlap.minMatch & mt.pairPeak >= 0.5 * mt.closure.peak;
pr = pr(use, :);
dx = (mt.U(pr(:, 2)) - mt.U(pr(:, 1))) - mt.pairL(use);
dy = mt.pairDy(use);
no = size(pr, 1);
Lk.a = [Lk.a; pr(:, 1)]; Lk.b = [Lk.b; pr(:, 2)];
Lk.m = [Lk.m; dx, dy]; Lk.q = [Lk.q; -[dx, dy] / 2];
Lk.sig = [Lk.sig; S.overlap.sigma_px * ones(no, 2)];
Lk.kind = [Lk.kind; 2 * ones(no, 1)];
Lk.peak = [nan(nl, 1); mt.pairPeak(use)];
end
