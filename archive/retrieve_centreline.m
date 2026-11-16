%% Retrieval path: camera frames in data/<dataset>/ -> centreline -> audio
% Tracks both groove edges in every frame (sub-pixel), takes their
% midpoint as the centreline, and plays it back like a turntable: stylus
% velocity, RIAA de-emphasis, band-pass to 20 Hz - 20 kHz. The band-pass
% is the continuity step; the tracker does not require edges to be
% continuous between rows.
%
% Run forward_sine.m or forward_music.m first. Only the frames and
% meta.mat are used for the reconstruction; truth.mat is opened inside
% retrieve_audio after it, for scoring. Lengths in micrometres (um).

clear; close all; clc;

dataset = 'music';   % 'sine', 'music', or a folder under data/setups/

dataDir = fullfile(project_root(), 'data', dataset);
runsDir = fullfile(project_root(), 'results', 'runs');

%% 1. Reconstruct

trackOpts.widthTolerance = 0.5;   % accept 0.5x - 1.5x the nominal width
trackOpts.trackingWindow = 8;     % max centre shift between rows (um)
trackOpts.startCentre = 0;        % groove position at the first row; pick
                                  % by hand for a real image
audioOpts.band = [20 20e3];       % Hz
audioOpts.fsOut = 48e3;           % Hz

tic;
r = retrieve_audio(dataDir, trackOpts, audioOpts);
fprintf('Reconstruction took %.0f s\n', toc);

%% 2. Scores

fprintf('\n%s, %s light, %.3f s of audio\n', r.meta.cam.name, ...
    r.meta.light.type, r.est.t(end));
fprintf('Rows with a detected edge pair: %.1f%%\n', 100*r.coverage);
fprintf('Centreline RMSE: %.3f um (detected rows), %.3f um (gaps filled)\n', ...
    r.rmseDetected, r.rmseFilled);
fprintf('Audio SNR against a perfect stylus: %.1f dB\n', r.snr);

if r.est.t(end) > 0.1
    if ~exist(runsDir, 'dir'), mkdir(runsDir); end
    name = strrep(dataset, '/', '_');
    scale = 0.9 / max(abs([r.ref.audio; r.est.audio]));
    audiowrite(fullfile(runsDir, [name '_true.wav']), scale*r.ref.audio, r.ref.fs);
    audiowrite(fullfile(runsDir, [name '_recovered.wav']), scale*r.est.audio, r.est.fs);
    fprintf('Wrote %s_true.wav and %s_recovered.wav to %s\n', name, name, runsDir);
end

%% 3. Figures

meta = r.meta;
y = meta.y;
halfWidth = meta.scene.depth * tand(meta.scene.includedAngle/2);
trueLeft = r.truth.xc - halfWidth;
trueRight = r.truth.xc + halfWidth;
err = r.xFilled - r.truth.xc;

% Frame with the largest error
frameErr = accumarray(ceil((1:numel(y))' / meta.frameRows), err.^2, [], @mean);
[~, kWorst] = max(frameErr);
[I, rows] = read_groove_frame(dataDir, meta, kWorst);
trShow = struct('left', r.tr.left(rows), 'right', r.tr.right(rows));
plot_edges(meta.x, y(rows), I, trShow, trueLeft(rows), trueRight(rows), ...
    r.xFilled(rows));

figure('Color', 'w');
plot(y(rows), r.truth.xc(rows), 'k-', 'LineWidth', 2);
hold on;
plot(y(rows), r.xFilled(rows), 'r.', 'MarkerSize', 4);
hold off;
xlabel('Along groove, y (\mum)');
ylabel('Lateral position, x (\mum)');
title(sprintf('True and tracked centreline (frame %d)', kWorst));
legend('True', 'Tracked', 'Location', 'best');
grid on;

plot_error_along_groove(y, {err}, {'Tracked centreline'}, []);
plot_error_histogram({err}, {'Tracked centreline'});

rowsShown = y(rows([1, round(end/2), end]));
plot_edge_profiles(meta.x, y(rows), I, trShow, trueLeft(rows), trueRight(rows), ...
    rowsShown, {'First row', 'Middle row', 'Last row'}, max(3, round(2 / meta.dy)));

tMid = r.est.t(end) / 2;
plot_audio(r.ref, r.est, [tMid, tMid + 0.02]);
