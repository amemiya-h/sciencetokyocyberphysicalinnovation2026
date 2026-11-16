%E02_SYNTHETIC_PARTB  Validate Part B on the synthetic video of E01.
%   Uses E01's Part A result (run E01_synthetic_partA first), runs
%   MUSIC_ON_SPIRAL, and compares the binned groove displacement with the
%   known music: after finding the constant time offset (Psi is only known
%   up to a constant), the error rms and the correlation.
T = synth_truth();
run = 'E01_synthetic_partA';
dirR = fullfile(project_root(), 'results', 'runs', run);
A = load(fullfile(dirR, 'partA.mat'));
isOct = exist('OCTAVE_VERSION', 'builtin') > 0;
dirV = fullfile(project_root(), 'data', 'synthetic');
if isOct, vf = fullfile(dirV, 'E01_synth_frames.mat'); else, vf = fullfile(dirV, 'E01_synth.avi'); end
% at 6 um/px a 32 kHz bin is only 0.45 px wide (method B4 table); use 12 kHz
% bins and a 5 kHz band so a bin is >= 1 px
over.music.binRate_Hz = 12000; over.music.bandHigh_Hz = 5000;
B = music_on_spiral(vf, A, 'RunName', run, 'Settings', over);

diary(fullfile(dirR, 'log.txt'));
fprintf('\n---- E02: Part B against the true music ----\n');
ok = ~isnan(B.x) & B.views > 0;
t = B.t(ok); x = B.x(ok);
truth = @(tt) T.tones(1, 1) * sin(2 * pi * T.tones(1, 2) * tt + T.tones(1, 3)) + ...
    T.tones(2, 1) * sin(2 * pi * T.tones(2, 2) * tt + T.tones(2, 3)) + ...
    T.tones(3, 1) * sin(2 * pi * T.tones(3, 2) * tt + T.tones(3, 3));
% constant time offset: music time is T*N on the blank groove; fitted and
% true time differ by a constant, measured on the blank grooves of frame 1
scan = video_scan(vf, settings_load(struct('microscope', struct('magnification', 148.8 / T.p))), T.p, ...
    fullfile(dirR, 'cache'), '-v7');
C = scan.B{1}; k1 = scan.pick(1);
gx = double(C(:, 1)) - (T.W + 1) / 2; gy = double(C(:, 2)) - (T.H + 1) / 2;
E = disc_eval(A.model, gx, gy, k1 * ones(size(gx)));
tf = T.Trev * (round(E.psi) - A.model.s * E.phi / (2 * pi));
[pt, ~, ~, pht] = synth_eval(T, k1, gx, gy);
tt = T.Trev * (round(pt) - T.s * pht / (2 * pi));
dt0 = -median(tf - tt);
best = [Inf, dt0];
for dt = dt0 + (-200:1:200) * 1e-6
    e = x - truth(t + dt); e = e - mean(e);
    v = mean(e.^2);
    if v < best(1), best = [v, dt]; end
end
fprintf('time offset from the models %.6f s, refined %+.1f us\n', dt0, 1e6 * (best(2) - dt0));
e = x - truth(t + best(2)); e = e - mean(e);
tr = truth(t + best(2));
fprintf('whole record, one time offset: error rms %.3f um vs music rms %.3f um\n', sqrt(mean(e.^2)), std(tr));
% short windows (20 ms): amplitude of each tone, residual, and the slow
% time warp (wow/flutter) left by the pose errors, from the 1230 Hz phase
tw = t + best(2);
edges = min(tw):0.02:max(tw);
wi = floor((tw - edges(1)) / 0.02) + 1;
nw = max(wi);
amp = nan(nw, 3); res = nan(nw, 1); ph = nan(nw, 1);
for j = 1:nw
    m = wi == j;
    if nnz(m) < 100, continue; end
    tt = tw(m); Am = ones(nnz(m), 1);
    for i = 1:3, f = T.tones(i, 2); Am = [Am, sin(2 * pi * f * tt), cos(2 * pi * f * tt)]; end %#ok<AGROW>
    c = Am \ x(m);
    for i = 1:3, amp(j, i) = hypot(c(2 * i), c(2 * i + 1)) / T.tones(i, 1); end
    ph(j) = atan2(c(5), c(4)) - T.tones(2, 3);
    res(j) = std(x(m) - Am * c);
end
ph = mod(ph + pi, 2 * pi) - pi;
warp = ph(~isnan(ph)) / (2 * pi * T.tones(2, 2));
gw = ~isnan(res); am = median(amp(gw, :), 1);
fprintf('20 ms windows: amplitude / true: %.3f (%g Hz), %.3f (%g Hz), %.3f (%g Hz); residual %.2f um\n', ...
    am(1), T.tones(1, 2), am(2), T.tones(2, 2), am(3), T.tones(3, 2), median(res(gw)));
fprintf('time warp from the 1230 Hz phase: rms %.1f us, as speed variation (flutter) %.4f%% rms\n', ...
    1e6 * std(warp), 100 * std(diff(warp)) / 0.02);
fprintf('residual = surface texture of the synthetic disc read as groove position (same in every view)\n');
diary('off');

