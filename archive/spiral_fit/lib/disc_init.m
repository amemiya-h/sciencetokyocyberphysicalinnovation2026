function [M, info] = disc_init(scan, mt, S, p, fk)
%DISC_INIT  Starting disc model for the pose fit: phase-locked chaining (method A4).
%   theta_k from the motion trace (mt), the revolution length gives the axis
%   distance, P from the lane spacing, the skew from the groove direction.
%   Then the frames are chained in order: the motion link (dv, the grooves
%   crossed between frames k-1 and k) predicts the change of the radial
%   spiral phase, the frame's own groove phase gives the fraction, and the
%   whole count is the one nearest the prediction. The lock margin of every
%   step is 0.5 - |link error| - phase error (turns), with the phase error
%   the circular spread of the frame's phases over the square root of its
%   number of grooves; steps below spiralFit.lockMarginMin_turns are
%   flagged. The spiral sense comes from the loop closure of the chain.
%   The chain places every frame's centre (c0_k = a + z_k a/|a|). The
%   overlaps (frame pairs one revolution apart, registered) must agree with
%   the chain's turn counts; otherwise it stops and names the stretch with
%   the smallest margins. Stops also if the starting phase error is above
%   spiralFit.initPhaseErrorMax_turns.
K = scan.K; W = scan.W; H = scan.H;
M = disc_model_new(S, p, W, H, mt.theta0, mt.R0, fk);
emax = S.spiralFit.initPhaseErrorMax_turns;
mmin = S.spiralFit.lockMarginMin_turns;

% --- 1. pitch from the lane spacing
ks = unique(round(linspace(1, K, min(K, 40))));
guess = S.record.pitch_um / p;
dd = [];
for k = ks
    r = scan.rd{k};
    [ux, ~, iu] = unique(r(:, 1));
    for j = 1:numel(ux)
        yy = sort(double(r(iu == j, 2)));
        dd = [dd; diff(yy)]; %#ok<AGROW>
    end
end
dd = dd(dd > 0.5 * guess & dd < 1.6 * guess);
P0 = double(median(dd)) * p;
fprintf('init: lane spacing %.2f px -> pitch %.1f um (settings %.0f um)\n', median(dd), P0, S.record.pitch_um);
if P0 < S.record.pitchMin_um || P0 > S.record.pitchMax_um
    error('disc_init:pitch', 'pitch %.1f um outside [%g, %g]', P0, S.record.pitchMin_um, S.record.pitchMax_um);
end
M.beta(:) = 1 / P0;

% --- 2. groove direction (skew) and pitch, by phase coherence
ks = unique(round(linspace(1, K, min(K, 30))));
Cs = sample_readings(scan, ks, 3000);
best = [-Inf, 0, 1];
for m = -0.08:0.004:0.08
    for f = 0.97:0.005:1.03
        q = coherence(set_skew(M, m, P0 * f), Cs);
        if q > best(1), best = [q, m, f]; end
    end
end
for m = best(2) + (-0.004:0.0005:0.004)
    for f = best(3) + (-0.005:0.001:0.005)
        q = coherence(set_skew(M, m, P0 * f), Cs);
        if q > best(1), best = [q, m, f]; end
    end
end
P0 = P0 * best(3);
M = set_skew(M, best(2), P0);
fprintf('init: groove slope %.4f (skew %.2f deg), pitch %.2f um, coherence %.3f\n', ...
    best(2), atand(best(2)), P0, best(1));
Ppx = P0 / p;                         % groove spacing, px

% --- 3. phase-locked chain; spiral sense from the overlaps
% Frames one revolution apart see the same disc patch. Their registration
% gives how far the view moved across the grooves in that revolution (the
% hand or a stage may move it radially), so the sense is decided by the
% overlaps against the chain, not by assuming the view came back to the
% same radius.
Ch = run_chain(M, scan, mt, Ppx, mmin);
[D, okD] = overlap_shift(place_centres(M, Ch, P0), mt, S, P0);
if okD == 0
    [D, okD] = closure_shift(Ch.R, mt);
    fprintf('init: no overlap pairs; chain closure over one revolution (fixed radius assumed)\n');
end
fprintf('init: with s = +1, the overlaps differ from the chain by %+.2f turns (median over %d pairs)\n', D, okD);
if abs(D) < 0.5
    sinfo = 'kept s = +1';
elseif abs(abs(D) - 2) < 0.5
    M.s = -1; M = disc_update(M);
    Ch = run_chain(M, scan, mt, Ppx, mmin);
    [D, okD] = overlap_shift(place_centres(M, Ch, P0), mt, S, P0);
    if okD == 0, D = closure_shift(Ch.R, mt); end
    sinfo = sprintf('switched to s = -1; now %+.2f turns', D);
else
    error('disc_init:sense', ['overlaps differ from the chain by %+.2f turns, ' ...
        'neither 0 (s=+1) nor 2 (s=-1): the motion trace or the chain is wrong'], D);
end
fprintf('init: spiral sense: %s\n', sinfo);
if abs(D) > emax
    error('disc_init:closure', 'closure residual %.2f turns exceeds %.2f', D, emax);
end
fprintf('init: chain link sign %+d (error of the link prediction with +: mean %.3f turns, with -: %.3f)\n', ...
    Ch.sign, Ch.errBoth(1), Ch.errBoth(2));
fprintf('init: lock margin per step: min %.3f, median %.3f turns (limit %.2f); link error median %.3f, max %.3f turns; phase error median %.3f\n', ...
    min(Ch.margin(2:end)), median(Ch.margin(2:end)), mmin, median(abs(Ch.linkErr(2:end))), max(abs(Ch.linkErr(2:end))), median(Ch.phaseErr));
flag = find(Ch.margin < mmin);
Ch.flag = flag(flag > 1);
fprintf('init: %d steps below the lock margin limit', numel(Ch.flag));
if ~isempty(Ch.flag)
    [~, io] = sort(Ch.margin(Ch.flag));
    w = Ch.flag(io(1:min(8, end)));
    fprintf('; smallest: ');
    fprintf('frame %d (%.2f) ', [w(:)'; Ch.margin(w)']);
end
fprintf('\n');
st = abs(diff(Ch.R));
fprintf('init: frame-to-frame chain step: median %.4f, max %.3f turns\n', median(st), max(st));

% --- 4. centres from the chain
[M, z] = place_centres(M, Ch, P0);
fprintf('init: chain places the centre %.1f px (%.2f mm) radially at most from the axis point; theta from the motion trace\n', ...
    max(abs(z)), max(abs(z)) * p / 1000);

% --- 5. pitch basis over the radii actually seen
Ca = sample_readings(scan, 1:max(1, round(K / 200)):K, 400);
E = disc_eval(M, Ca(:, 1), Ca(:, 2), Ca(:, 3));
h = S.record.pitchKnotTurns * P0;
M = disc_set_pitch_basis(M, min(E.r) - 2 * h, max(E.r) + 2 * h, h, P0);
M = disc_update(M);

% --- 6. starting phase error
[rk2, qk2] = frame_phase(M, scan);
err0 = abs(rk2 - round(rk2));
fprintf('init: starting phase error per frame: median %.3f, max %.3f turns (limit %.2f); coherence median %.2f\n', ...
    median(err0), max(err0), emax, median(qk2));
if max(err0) > emax
    error('disc_init:start', 'starting phase error %.2f turns > %.2f: stopping rather than risk a slipped turn', max(err0), emax);
end

% --- 7. overlaps against the chain's turn counts
ov = struct('k1', [], 'k2', [], 'turns', [], 'frac', [], 'peak', []);
pr = mt.pairs;
use = mt.pairPeak >= S.overlap.minMatch & mt.pairPeak >= 0.5 * mt.closure.peak;
pr = pr(use, :);
if ~isempty(pr)
    dx = (mt.U(pr(:, 2)) - mt.U(pr(:, 1))) - mt.pairL(use);
    dy = mt.pairDy(use);
    q = -[dx, dy] / 2;
    c1 = M.c(pr(:, 1), :); c2 = M.c(pr(:, 2), :);
    dth = M.theta(pr(:, 2)) - M.theta(pr(:, 1));
    v = q - c1;
    pred = c2 + [cos(dth) .* v(:, 1) - sin(dth) .* v(:, 2), sin(dth) .* v(:, 1) + cos(dth) .* v(:, 2)] - q;
    e = (pred - [dx, dy]) * (M.a / norm(M.a)) * (M.p / P0);   % radial disagreement, turns
    ov.k1 = pr(:, 1); ov.k2 = pr(:, 2); ov.turns = round(e); ov.frac = e - round(e); ov.peak = mt.pairPeak(use);
    fprintf('init: overlaps: %d pairs one revolution apart (match >= %.2f); chain turn disagreement: %d pairs; radial residual median |.| %.3f turns, max %.3f\n', ...
        numel(e), S.overlap.minMatch, nnz(ov.turns ~= 0), median(abs(ov.frac)), max(abs(ov.frac)));
    if any(ov.turns ~= 0)
        bad = find(ov.turns ~= 0);
        for i = bad(:)'
            seg = ov.k1(i) + 1:ov.k2(i);
            [mn, im] = min(Ch.margin(seg));
            fprintf('  pair %d -> %d disagrees by %+d turn(s); smallest lock margin in between: %.3f at frame %d\n', ov.k1(i), ov.k2(i), ov.turns(i), mn, seg(im));
        end
        error('disc_init:overlap', 'the chain disagrees with %d overlaps by whole turns: a slip between the frames named above', numel(bad));
    end
else
    fprintf('init: overlaps: no accepted pairs (match >= %.2f)\n', S.overlap.minMatch);
end
info = struct('P0', P0, 'slope', best(2), 'skew_deg', atand(best(2)), 'coherence', best(1), ...
    's', M.s, 'closureTurns', D, 'startErrMax', max(err0), 'chain', Ch, 'overlaps', ov, 'M0', M);
end

function Ch = run_chain(M, scan, mt, Ppx, mmin) %#ok<INUSD>
% frame phases, then the chain with the motion links (the shift across the
% grooves: dv less the groove slope times du); the link sign is
% checked on the data (both signs are chained, the one the grooves agree with is used)
K = scan.K;
[f, q] = frame_phase(M, scan);
sg = sqrt(-2 * log(min(max(q, 1e-3), 1 - 1e-9))) / (2 * pi);
nGr = max(1, scan.H / Ppx);
Ch.phaseErr = min(0.5, sg / sqrt(nGr));
dv = mt.dv(:); du = mt.du(:);
m = -M.a(1) / M.a(2);                 % groove slope: the grooves run along (1, m), the rotation moves content that way
across = (dv - m * du) / sqrt(1 + m^2);   % content shift across the grooves, px
best = [];
errB = zeros(1, 2); Rs = cell(1, 2); les = cell(1, 2);
for si = 1:2
    sgn = [1, -1] * M.sgnY;
    R = zeros(K, 1); le = zeros(K, 1);
    R(1) = f(1);
    for k = 2:K
        pred = R(k - 1) + sgn(si) * across(k) / Ppx;
        R(k) = f(k) + round(pred - f(k));
        le(k) = pred - R(k);
    end
    errB(si) = mean(abs(le(2:end)));
    Rs{si} = R; les{si} = le;
    if si == 1 || errB(si) < best.err
        best = struct('err', errB(si), 'R', R, 'le', le, 'sign', sgn(si) / M.sgnY);
    end
end
if min(errB) > 0.7 * max(errB)
    fprintf('init: WARNING the data do not decide the sign of the motion link (mean link error %.3f with +, %.3f with -); using +\n', errB(1), errB(2));
    best = struct('err', errB(1), 'R', Rs{1}, 'le', les{1}, 'sign', 1);
end
Ch.R = best.R; Ch.linkErr = best.le; Ch.sign = best.sign; Ch.errBoth = errB;
Ch.f = f; Ch.coh = q;
Ch.margin = 0.5 - abs(Ch.linkErr) - Ch.phaseErr;
Ch.margin(1) = NaN;
end

function M = set_skew(M, m, P)
R = M.R0;
ay = M.sgnY * R / sqrt(1 + m^2);
M.a = [-m * ay; ay];
M.c0 = repmat(M.a', size(M.c0, 1), 1);
M.beta(:) = 1 / P;
M = disc_update(M);
end

function C = sample_readings(scan, ks, nmax)
C = cell(numel(ks), 1);
for i = 1:numel(ks)
    r = scan.rd{ks(i)};
    j = 1:max(1, floor(size(r, 1) / nmax)):size(r, 1);
    C{i} = [double(r(j, 1:2)), ks(i) * ones(numel(j), 1)];
end
C = cat(1, C{:});
end

function q = coherence(M, C)
E = disc_eval(M, C(:, 1), C(:, 2), C(:, 3));
z = exp(2i * pi * E.psi);
[~, ~, g] = unique(C(:, 3));
q = mean(abs(accumarray(g, z) ./ accumarray(g, 1)));
end

function [f, qk] = frame_phase(M, scan)
% circular mean of the phase residual in each frame, in (-0.5, 0.5] turns
C = sample_readings(scan, 1:scan.K, 1500);
E = disc_eval(M, C(:, 1), C(:, 2), C(:, 3));
z = accumarray(C(:, 3), exp(2i * pi * E.psi), [scan.K, 1]) ./ max(1, accumarray(C(:, 3), 1, [scan.K, 1]));
f = angle(z) / (2 * pi);
qk = abs(z);
end

function [D, n] = closure_shift(rk, mt)
th = mt.theta0; K = numel(th);
dirn = sign(mt.L);
d = nan(K, 1);
tol = 0.25 * pi / mt.R0 * 1000;  % a few hundred px along the groove
for k = 1:K
    [dmin, k2] = min(abs(th - th(k) - dirn * 2 * pi));
    if dmin < tol && k2 > k
        d(k) = rk(k2) - rk(k);
    end
end
n = nnz(~isnan(d));
if n == 0
    error('disc_init:noOverlap', 'no frames one revolution apart');
end
D = median(d(~isnan(d)));
end

function [M, z] = place_centres(M, Ch, P0)
% the chain places every frame's centre along the axis direction
R = Ch.R - round(median(Ch.R));
z = R / (M.p / P0);                   % px
ah = M.a / norm(M.a);
M.c0 = repmat(M.a', numel(R), 1) + z * ah';
M = disc_update(M);
end

function [D, n] = overlap_shift(M, mt, S, P0)
% median radial disagreement (turns) between the registered overlap pairs
% and the poses placed by the chain; same formula as the overlap check (step 7)
use = mt.pairPeak >= S.overlap.minMatch & mt.pairPeak >= 0.5 * mt.closure.peak;
pr = mt.pairs(use, :); n = size(pr, 1); D = NaN;
if n == 0, return; end
dx = (mt.U(pr(:, 2)) - mt.U(pr(:, 1))) - mt.pairL(use);
dy = mt.pairDy(use);
q = -[dx, dy] / 2;
c1 = M.c(pr(:, 1), :); c2 = M.c(pr(:, 2), :);
dth = M.theta(pr(:, 2)) - M.theta(pr(:, 1));
v = q - c1;
pred = c2 + [cos(dth) .* v(:, 1) - sin(dth) .* v(:, 2), sin(dth) .* v(:, 1) + cos(dth) .* v(:, 2)] - q;
D = median((pred - [dx, dy]) * (M.a / norm(M.a)) * (M.p / P0));
end
