function B = music_on_spiral(videoFile, A, varargin)
%MUSIC_ON_SPIRAL  Part B: the music on the given spiral.
%   B = MUSIC_ON_SPIRAL(videoFile, A, Name, Value, ...) takes the disc
%   model A from DISC_MODEL_FIT as given and (method B1-B6):
%     picks frames covering the video at video.views views per point,
%     reads every column of every turn by demodulating the image against
%     the spiral phase (GROOVE_DEMOD_FRAME: Fourier coefficients of the
%     cross-groove profile per turn and column, weighted by contrast;
%     nothing is deleted),
%     maps each reading to music time through Psi, averages time bins,
%     and writes the sound (raw and listenable _eq WAVs).
%   Output in results/runs/<RunName>/: partB.mat (-v7), partB_checks.png,
%   <video>_mono/_stereo(_eq).wav, and the log.
%   Options: 'RunName' (default <video>), 'Settings' (struct merged into
%   settings.json).
ip = inputParser;
ip.addParameter('RunName', '');
ip.addParameter('Settings', struct());
ip.parse(varargin{:});
o = ip.Results;
if ~exist(videoFile, 'file') && exist(fullfile(project_root(), videoFile), 'file')
    videoFile = fullfile(project_root(), videoFile);
end
[~, vname] = fileparts(videoFile);
if isempty(o.RunName), o.RunName = vname; end
S = settings_load(o.Settings);
S.microscope.magnification = A.settings.microscope.magnification;
S.microscope.mirrored = A.settings.microscope.mirrored;
R = run_open(o.RunName, S);
cleanup = onCleanup(@() diary('off'));
M = A.model;
T = 60 / S.record.rpm;
fprintf('Part B: %s (pixel %.4f um, spiral sense %+d)\n', videoFile, M.p, M.s);
fprintf('bins %g Hz = %.2f us; band %g-%g Hz; RIAA %d; views %d\n', S.music.binRate_Hz, ...
    1e6 / S.music.binRate_Hz, S.music.bandLow_Hz, S.music.bandHigh_Hz, S.music.riaa, S.video.views);
if S.music.binRate_Hz < 2 * S.music.bandHigh_Hz
    error('music_on_spiral:nyquist', 'binRate_Hz %g is below 2 x bandHigh_Hz', S.music.binRate_Hz);
end
pxPerBin = 2 * pi * A.checks.r_range_mm * 1000 / (T * S.music.binRate_Hz * M.p);
fprintf('bin width %.2f..%.2f px (must stay >= 1)\n', min(pxPerBin), max(pxPerBin));

% B1-B3: the frames and their full-resolution groove centres were chosen
% and measured in the single decoding pass (VIDEO_SCAN, cached); here they
% are only mapped through the disc model
scan = video_scan(videoFile, S, M.p, R.cache, R.fmt);
pick = scan.pick; Bs = scan.B; Pp = scan.Pp;
fprintf('frames: %d chosen during the scan (%d views)\n', numel(pick), S.video.views);
pool_get();
tic;
Rb = cell(1, numel(pick)); sb = cell(1, numel(pick));
parfor j = 1:numel(pick)
    [r, sti] = readings_to_bins(M, pick(j), Bs{j}, S);
    Rb{j} = [r, pick(j) * ones(size(r, 1), 1)];
    sb{j} = sti;
end
Rall = cat(1, Rb{:});
st = [sb{:}];
tot = sum([st.n]);
fprintf('readings: %d groove centres mapped to music time in %.1f s; weight < 0.25 for %.1f%% (low contrast: dust, scratches, blur); none deleted\n', ...
    tot, toc, 100 * sum([st.lowWeight] .* [st.n]) / tot);
fprintf('profile: contrast %.1f grey levels (median), width %.1f um\n', median([st.contrast]), median([st.width_um]));
fprintf('grooves: %.1f per frame (tracks); the model''s round(Psi) numbered %.2f%% of them differently; %.1f%% of readings without a usable position (dust on the groove, weight 0); %.1f%% referenced to their own groove trend (model off by > 1/4 turn)\n', ...
    mean([st.grooves]), 100 * sum([st.renumbered]) / sum([st.grooves]), 100 * sum([st.noPosition] .* [st.n]) / tot, 100 * sum([st.ownTrend] .* [st.n]) / tot);
pl = cat(1, st.plane);
fprintf('per-frame pose correction (plane): offset rms %.2f um (max %.2f), x-slope rms %.2f um, y-slope rms %.2f um\n', ...
    sqrt(mean(pl(:, 1).^2)), max(abs(pl(:, 1))), sqrt(mean(pl(:, 2).^2)), sqrt(mean(pl(:, 3).^2)));

% B4: align the views in time (small along-groove pose corrections), then bin
B0 = music_bins(Rall, S);
fprintf('agreement between views before alignment: %.2f um\n', B0.spread_um);
clear B0
[~, na] = disc_tangent(M);
binPx = 2 * pi * na / (T * S.music.binRate_Hz);        % px along the groove per bin at the image centre
[Rall, shb] = views_align(Rall, S, 3, ceil(S.video.alignMax_px / binPx));
fprintf('per-frame time shifts: rms %.2f us = %.2f px along the groove (max %.2f px)\n', ...
    1e6 * sqrt(mean(shb.^2)) / S.music.binRate_Hz, sqrt(mean(shb.^2)) * binPx, max(abs(shb)) * binPx);
B = music_bins(Rall, S);
% B6 checks. The output covers the fully seen turns: the turns at the very
% top and bottom of the band are only partly seen (at the frame edge), so
% the span starts and ends where a turn's worth of bins is >= 90% covered.
cov = movmean(double(B.views > 0), round(T * S.music.binRate_Hz));
full = find(cov >= 0.9);
span = full(1):full(end);
fprintf('output span: %.1f s of %.1f s seen (partial edge turns left out)\n', numel(span) / S.music.binRate_Hz, ...
    (find(B.views > 0, 1, 'last') - find(B.views > 0, 1)) / S.music.binRate_Hz);
vw = B.views(span);
Pm = A.checks.P_mean;
x = B.x(span);
okd = ~isnan(x(1:end-1)) & ~isnan(x(2:end));
step = abs(diff(x)); step = step(okd);
nJump = nnz(step > Pm / 4);
nSlip = nnz(B.binSpread(span) > Pm / 4);
ck.viewsMedian = median(vw(vw > 0)); ck.viewsMin = min(vw(vw > 0));
ck.emptyPct = 100 * mean(vw == 0);
ck.spread_um = B.spread_um;
ck.jumps = nJump; ck.slipBins = nSlip;
ck.musicRms_um = 1.4826 * median(abs(x(~isnan(x)) - median(x(~isnan(x)))));
ck.duration_s = numel(span) / S.music.binRate_Hz;
fprintf('\n---- Part B checks ----\n');
fprintf('music: %.1f s (t = %.2f..%.2f s), %d bins\n', ck.duration_s, B.t(span(1)), B.t(span(end)), numel(span));
fprintf('views per bin: median %g, min %g (non-empty); empty bins %.2f%%\n', ck.viewsMedian, ck.viewsMin, ck.emptyPct);
fprintf('agreement between views: spread %.2f um (robust, per view; music rms %.2f um)\n', ck.spread_um, ck.musicRms_um);
fprintf('jumps: %d   (bin-to-bin steps > P/4 = %.0f um)\n', nJump, Pm / 4);
fprintf('slip suspects: %d bins where views disagree by > P/4\n', nSlip);

% B5
Bo = B; f = {'x', 'xIn', 'xOut', 'views', 't', 'weight', 'binSpread'};
for i = 1:numel(f), Bo.(f{i}) = B.(f{i})(span); end
snd = music_sound(Bo, S, fullfile(R.dir, vname));

% figure
try
fig = figure('Visible', 'off', 'Position', [50 50 1500 900]);
subplot(2, 2, 1); plot(B.t(span), x); grid on; xlabel('t (s)'); ylabel('x (um)');
title(sprintf('groove displacement, %d jumps', nJump));
subplot(2, 2, 2);
mid = span(round(end / 2)); z = max(1, mid - 800):min(numel(B.t), mid + 800);
plot(B.t(z) * 1e3, B.x(z), 'k', B.t(z) * 1e3, B.xIn(z), B.t(z) * 1e3, B.xOut(z)); grid on;
legend('centre', 'inner wall', 'outer wall'); xlabel('t (ms)'); ylabel('um'); title('50 ms detail');
subplot(2, 2, 3); histogram_(vw, 0:max(vw) + 1); xlabel('views per bin'); ylabel('bins'); grid on;
title(sprintf('views: median %g, empty %.2f%%', ck.viewsMedian, ck.emptyPct));
subplot(2, 2, 4); plot(B.t(span), movmedian(B.binSpread(span), 321, 'omitnan')); grid on;
xlabel('t (s)'); ylabel('um'); title(sprintf('spread between views (running median), overall %.2f um', B.spread_um));
print(fig, fullfile(R.dir, 'partB_checks.png'), '-dpng', '-r110'); close(fig);
catch err
    fprintf('figure failed: %s\n', err.message);
end

out = struct('t', B.t(span), 'x', B.x(span), 'xIn', B.xIn(span), 'xOut', B.xOut(span), ...
    'views', B.views(span), 'binSpread', B.binSpread(span));
out.pick = pick; out.checks = ck; out.sound = snd; out.settings = S;
save(fullfile(R.dir, 'partB.mat'), '-struct', 'out', R.fmt);
B.checks = ck; B.sound = snd; B.pick = pick;
fprintf('saved %s\n', fullfile(R.dir, 'partB.mat'));
run_close(R);
end

function histogram_(v, edges)
c = accumarray(min(numel(edges) - 1, max(1, floor(v(:)) - edges(1) + 1)), 1, [numel(edges) - 1, 1]);
bar(edges(1:end-1), c, 1);
end
