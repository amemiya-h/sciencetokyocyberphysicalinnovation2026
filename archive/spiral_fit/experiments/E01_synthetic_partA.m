%E01_SYNTHETIC_PARTA  Validate Part A on a synthetic video with known truth.
%   Renders a small video of a known spiral (pitch, poses, eccentricity,
%   wobble, distortion, music; spiral sense -1), runs DISC_MODEL_FIT on it
%   and compares: the turn identity (Psi_fit - Psi_true must be one
%   constant over all frames), the spiral centre path, the rotation, P(r)
%   and the distortion. Output: results/runs/E01_synthetic_partA/.
rng(1);
T = synth_truth();
run = 'E01_synthetic_partA';
dirR = fullfile(project_root(), 'results', 'runs', run);
if ~exist(dirR, 'dir'), mkdir(dirR); end
isOct = exist('OCTAVE_VERSION', 'builtin') > 0;
dirV = fullfile(project_root(), 'data', 'synthetic');   % data/*/ is git-ignored
if ~exist(dirV, 'dir'), mkdir(dirV); end
if isOct, vf = fullfile(dirV, 'E01_synth_frames.mat'); else, vf = fullfile(dirV, 'E01_synth.avi'); end
if ~exist(vf, 'file')
    fprintf('rendering %d synthetic frames...\n', T.K);
    if isOct
        F = zeros(T.H, T.W, T.K, 'uint8');
        for k = 1:T.K, F(:, :, k) = synth_render(T, k); end
        fps = T.fps; save(vf, 'F', 'fps', '-v7');
    else
        vw = VideoWriter(vf, 'Motion JPEG AVI'); vw.Quality = 95; vw.FrameRate = T.fps;
        open(vw);
        for k = 1:T.K, writeVideo(vw, synth_render(T, k)); end
        close(vw);
    end
end
mag = 148.8 / T.p;
A = disc_model_fit(vf, 'RunName', run, 'Magnification', mag);

% ---- compare with the truth (appended to the run log)
diary(fullfile(dirR, 'log.txt'));
M = A.model;
fprintf('\n---- E01: comparison with the truth ----\n');
fprintf('spiral sense: fitted %+d, true %+d\n', M.s, T.s);
% turn identity on a grid of points in every frame
[gx, gy] = meshgrid(linspace(-0.45, 0.45, 9) * T.W, linspace(-0.45, 0.45, 7) * T.H);
off = zeros(T.K, 1); spread = off; dr = off; dP = off; dd = off;
for k = 1:T.K
    E = disc_eval(M, gx(:), gy(:), k * ones(numel(gx), 1));
    [pt, rt, Pt] = synth_eval(T, k, gx(:), gy(:));
    dpsi = E.psi - pt;
    off(k) = median(dpsi); spread(k) = max(abs(dpsi - off(k)));
    dr(k) = median(E.r - rt);
    dP(k) = sqrt(mean((1 ./ E.g - Pt).^2));
    dd(k) = sqrt(mean((E.d - synth_distortion(T, gx(:), gy(:))).^2));
end
o0 = median(off);
fprintf('turn identity: Psi_fit - Psi_true = %.3f + (per frame) range [%+.4f, %+.4f] turns; within-frame max %.4f turns\n', ...
    o0, min(off - o0), max(off - o0), max(spread));
if max(abs(off - o0)) < 0.1 && max(spread) < 0.1
    fprintf('  -> PASS: one constant offset for every frame, no slipped turn\n');
else
    fprintf('  -> FAIL: turn identity not constant\n');
end
fprintf('radius: fitted - true = %.1f um (a common offset only renames the turns), varies by %.2f um over frames\n', ...
    median(dr), max(dr) - min(dr));
cErr = M.c - T.c;
cErr = cErr - mean(cErr, 1);
fprintf('spiral centre path: error after removing the common offset: rms %.2f px = %.2f um, max %.2f px\n', ...
    sqrt(mean(sum(cErr.^2, 2))), sqrt(mean(sum(cErr.^2, 2))) * T.p, max(hypot(cErr(:, 1), cErr(:, 2))));
the = (M.theta - (T.theta - T.theta(1)));
fprintf('rotation: theta error rms %.2e rad = %.2f px along the groove (after removing the offset %.2e rad)\n', ...
    std(the), std(the) * norm(T.a), mean(the));
fprintf('mean axis distance: fitted %.1f px, true %.1f px; skew fitted %.3f deg, true %.3f deg\n', ...
    norm(M.a), norm(T.a), A.checks.skew_deg, atan2d(-T.a(1), T.a(2)));
fprintf('pitch: rms error over the visible band %.2f um (true P varies 114-126 um)\n', sqrt(mean(dP.^2)));
fprintf('distortion: rms error %.2f px (true field %.2f px p-p)\n', sqrt(mean(dd.^2)), A.checks.distortionPP_px);
diary('off');

