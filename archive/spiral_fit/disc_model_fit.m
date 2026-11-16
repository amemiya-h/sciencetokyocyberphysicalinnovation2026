function A = disc_model_fit(videoFile, varargin)
%DISC_MODEL_FIT  Part A: the disc model of a microscope video of a record.
%   A = DISC_MODEL_FIT(videoFile, Name, Value, ...) poses every frame
%   (spiral centre c_k, rotation theta_k), and fits the pitch P(r) and the
%   lens distortion, by the spiral-phase fit of docs/METHOD_groove_inverse_problem.md.
%   Writes results/runs/<RunName>/partA.mat (-v7), partA_checks.png and
%   log.txt; slow steps are cached in results/runs/<RunName>/cache.
%
%   Options:
%     'RunName'        default: <video name>_partA
%     'Magnification'  overrides settings microscope.magnification
%     'Settings'       struct merged into code/settings.json
%     'MaxFrames'      use only the first n frames (tests)
%     'ChunkFrames'    frames per parfor chunk in the fit (default 10)
%
%   A.frames: table-like struct with k, t (s), cx, cy (spiral centre, px,
%   1-based image coordinates), cxc, cyc (about the image centre), theta
%   (rad). A.model: the full model (see DISC_MODEL_NEW). A.pitch: r (um),
%   P (um). A.checks: the method A6 checks. A.init: the chain (A4).
ip = inputParser;
ip.addParameter('RunName', '');
ip.addParameter('Magnification', []);
ip.addParameter('Settings', struct());
ip.addParameter('MaxFrames', Inf);
ip.addParameter('ChunkFrames', 10);
ip.parse(varargin{:});
o = ip.Results;
if ~exist(videoFile, 'file') && exist(fullfile(project_root(), videoFile), 'file')
    videoFile = fullfile(project_root(), videoFile);
end
[~, vname] = fileparts(videoFile);
if isempty(o.RunName), o.RunName = [vname '_partA']; end
S = settings_load(o.Settings);
if ~isempty(o.Magnification), S.microscope.magnification = o.Magnification; end
p = S.microscope.pixelAt1x_um / S.microscope.magnification;
R = run_open(o.RunName, S);
cleanup = onCleanup(@() diary('off'));
fprintf('Part A: %s\n', videoFile);
fprintf('magnification %g -> pixel %.4f um; nominal pitch %g um = %.1f px; downsample %d; stages: %s\n', ...
    S.microscope.magnification, p, S.record.pitch_um, S.record.pitch_um / p, S.video.downsample, ...
    strjoin(cellstr(S.spiralFit.stages(:)'), ', '));
fprintf('settings: %s\n', jsonencode(S));

% A5: every frame, downsampled
scan = video_scan(videoFile, S, p, R.cache, R.fmt, o.MaxFrames);
% Part A uses the groove readings whose position is usable
scan.rd = cellfun(@(r) r(r(:, 6) > 0, 1:5), scan.rd, 'UniformOutput', false);
vs = vsrc_open(videoFile);

% motion trace and loop closure
key = struct('video', vname, 'K', scan.K, 'overlap', S.overlap, 'mag', S.microscope.magnification);
[ok, D] = cache_get(fullfile(R.cache, 'motion.mat'), key);
if ok
    mt = D.mt; fprintf('motion trace: loaded from cache\n');
else
    mt = motion_trace(scan, S, vs);
    cache_put(fullfile(R.cache, 'motion.mat'), key, struct('mt', mt), R.fmt);
end

% initial model: phase-locked chain (A4)
fk = 1:S.spiralFit.fitFrameStep:scan.K;
key.record = S.record; key.spiralFit = S.spiralFit; key.micro = S.microscope; key.chain = 2;
[ok, D] = cache_get(fullfile(R.cache, 'init.mat'), key);
if ok
    M = D.M; info = D.info; fprintf('initial model: loaded from cache\n');
else
    [M, info] = disc_init(scan, mt, S, p, fk);
    cache_put(fullfile(R.cache, 'init.mat'), key, struct('M', M, 'info', info), R.fmt);
end

% readings in chunks of fitted frames for the parfor fit: [x y k n], n the
% turn number from counting the frame's grooves against the chain (A4)
nf = o.ChunkFrames;
nc = ceil(numel(fk) / nf);
chunks = cell(nc, 1);
renum = 0; ngr = 0;
for i = 1:nc
    ks = fk((i - 1) * nf + 1:min(numel(fk), i * nf));
    c = cell(numel(ks), 1);
    for j = 1:numel(ks)
        r = scan.rd{ks(j)};
        E = disc_eval(M, r(:, 1), r(:, 2), ks(j) * ones(size(r, 1), 1));
        [n, rn] = disc_turns(E.psi, r(:, 5), M.sgnY);
        renum = renum + rn; ngr = ngr + max(r(:, 5));
        c{j} = [r(:, 1:2), single(ks(j)) * ones(size(r, 1), 1, 'single'), single(n)];
    end
    chunks{i} = cat(1, c{:});
end
fprintf('fit data: %d readings from every %d. frame, in %d chunks; turn numbers by counting grooves (%.2f%% of tracks differ from round(Psi) of the start model)\n', ...
    sum(cellfun(@(c) size(c, 1), chunks)), S.spiralFit.fitFrameStep, nc, 100 * renum / max(1, ngr));
Lk = disc_link_set(M, mt, scan, S, info.P0 / p);
fprintf('links: %d motion links between consecutive frames, %d overlaps\n', nnz(Lk.kind == 1), nnz(Lk.kind == 2));
scan.rd = [];

pool_get();
[M, hist] = disc_phase_fit(M, chunks, Lk, S, R);
M.a = mean(M.c, 1)';          % reference axis point for Part B (mean centre)
ck = disc_checks(M, chunks, mt, scan, S, R, vs, info, Lk);

% output
fr.k = (1:scan.K)'; fr.t = scan.t;
fr.cxc = M.c(:, 1); fr.cyc = M.c(:, 2);
fr.cx = M.c(:, 1) + (M.W + 1) / 2; fr.cy = M.c(:, 2) + (M.H + 1) / 2;
fr.theta = M.theta; fr.focus = scan.focus;
rg = linspace(ck.r_range_mm(1), ck.r_range_mm(2), 200)' * 1000;
A.frames = fr;
A.model = M;
A.pitch = struct('r', rg, 'P', 1 ./ (b3((rg - M.rC') / M.rh) * M.beta));
A.distortion = struct('powers', M.dpow, 'coef_px', M.alpha);
A.checks = ck; A.init = info; A.fitHistory = hist;
A.motion = rmfield(mt, {'pairs'});
A.video = videoFile; A.settings = S; A.pixel_um = p;
save(fullfile(R.dir, 'partA.mat'), '-struct', 'A', R.fmt);
fprintf('saved %s\n', fullfile(R.dir, 'partA.mat'));
run_close(R);
end
