%VISUALIZE_STEPS  One figure per step of the method, drawn on real data.
%
% For slides. Works a short run of frames through the real pipeline and
% draws what each step sees. Needs the video and the finished result of
% process_freehand_video (the .mat it saved). Figures are saved as PNG.
% Edit the marked lines.

addpath(fileparts(fileparts(mfilename('fullpath'))));

% --- What to show (EDIT) -----------------------------------------------------
videoFile  = 'data/keyence_recording/20261029_163032.avi';
resultFile = 'results/runs/20261029_163032/result.mat';   % saved by process_freehand_video
frames     = 300:330;                        % a stretch where the disc moved steadily
outFolder  = 'results/figures';
cfg = groove.defaultConfig();
cfg.camera.pixelSizeUm      = 148.8 / 30;
cfg.camera.spindleDirection = 'down';

result = load(resultFile);
source = groove.io.videoFrameSource(videoFile);
viz = groove.viz.collectSteps(source, cfg, frames, result.ring, result.report);
if ~exist(outFolder, 'dir'), mkdir(outFolder); end
red = [0.85 0.2 0.15];  blue = [0.1 0.4 0.8];  grey = [0.6 0.6 0.6];

% --- 1. The image and the groove edges found in it ---------------------------
figure('Color', 'w', 'Position', [100 100 1100 480]);
subplot(1, 2, 1);
imagesc(viz.zoomCols, viz.zoomRows, viz.frame(viz.zoomRows, viz.zoomCols)); colormap(gray); axis image; hold on
% Colours follow the channels: inner edge (left) red, outer edge (right) blue.
if strcmpi(cfg.camera.spindleDirection, 'down')
    topColour = blue;  bottomColour = red;
else
    topColour = red;   bottomColour = blue;
end
plot(viz.zoomCols, viz.edgeTop.',    'Color', topColour,    'LineWidth', 1.2);
plot(viz.zoomCols, viz.edgeBottom.', 'Color', bottomColour, 'LineWidth', 1.2);
title('Groove edges found in the image'); xlabel('column (pixels)'); ylabel('row (pixels)');
subplot(1, 2, 2);
plot(viz.profileRows, viz.profile, 'k-o', 'MarkerSize', 3); hold on
level = interp1(viz.profileRows, viz.profile, viz.crossTop);
plot(viz.crossTop,    level, 'v', 'Color', topColour,    'MarkerFaceColor', topColour);
level = interp1(viz.profileRows, viz.profile, viz.crossBottom);
plot(viz.crossBottom, level, '^', 'Color', bottomColour, 'MarkerFaceColor', bottomColour);
title('Brightness down one column: edges to a fraction of a pixel'); xlabel('row (pixels)'); ylabel('brightness');
saveFigure(outFolder, 'step1_edges');

% --- 2. From a tilted, curved line to the wiggle ------------------------------
figure('Color', 'w', 'Position', [100 100 1100 480]);
subplot(2, 1, 1);
plot(viz.grooveColumns, viz.grooveCentrePx, 'k'); hold on
plot(viz.grooveColumns, viz.grooveFitPx, 'Color', red, 'LineWidth', 1.5);
set(gca, 'YDir', 'reverse'); title('One groove''s centre line, and the tilt and curve all grooves share'); ylabel('row (pixels)');
subplot(2, 1, 2);
plot(viz.grooveColumns, viz.grooveWiggle, 'Color', blue);
title('What is left: the wiggle the music made'); xlabel('column (pixels)'); ylabel('micrometres');
saveFigure(outFolder, 'step2_wiggle');

% --- 3. How far the disc moved between two frames -----------------------------
figure('Color', 'w', 'Position', [100 100 1100 600]);
columns = 1:numel(viz.pairWiggleA);
subplot(3, 1, 1);
plot(columns, viz.pairWiggleA, 'Color', red); hold on; plot(columns, viz.pairWiggleB, 'Color', blue);
title('The same groove in two consecutive frames'); ylabel('micrometres'); legend('frame 1', 'frame 2');
subplot(3, 1, 2);
plot(viz.pairLags, viz.pairMatch, 'k'); hold on
plot([viz.pairShiftPx viz.pairShiftPx], [min(viz.pairMatch) 1], '--', 'Color', red);
title(sprintf('How well they match at each trial shift: best at %.1f pixels', viz.pairShiftPx)); ylabel('match'); xlabel('trial shift (pixels)');
subplot(3, 1, 3);
plot(columns, viz.pairWiggleA, 'Color', red); hold on; plot(columns - viz.pairShiftPx, viz.pairWiggleB, 'Color', blue);
title('Frame 2 slid back by that shift'); ylabel('micrometres'); xlabel('column (pixels)');
saveFigure(outFolder, 'step3_shift');

% --- 4. Many views of the same groove, averaged --------------------------------
figure('Color', 'w', 'Position', [100 100 1100 420]);
plot(viz.viewBins, viz.viewLines.', 'Color', grey); hold on
plot(viz.viewBins, viz.viewMean, 'Color', red, 'LineWidth', 1.8);
title(sprintf('%d views of one stretch of groove (grey) and their average (red)', size(viz.viewLines, 1)));
xlabel('position along the groove (pixels)'); ylabel('micrometres');
saveFigure(outFolder, 'step4_views');

% --- 5. Closing the revolution -------------------------------------------------
figure('Color', 'w', 'Position', [100 100 1100 420]);
n = min(1500, numel(viz.closureEarly));
plot(1:n, viz.closureEarly(1:n), 'Color', blue, 'LineWidth', 1.2); hold on
plot(1:n, viz.closureLate(1:n),  'Color', red);
title('One revolution later, a groove band shows what its neighbour showed at the start');
legend('band n+1 at the start', 'band n one revolution later'); xlabel('position along the groove (pixels)'); ylabel('micrometres');
saveFigure(outFolder, 'step5_closure');

% --- 6. From edges to sound ----------------------------------------------------
figure('Color', 'w', 'Position', [100 100 1100 520]);
subplot(2, 1, 1);
plot(viz.musicTimeMs, viz.musicInner, 'Color', red); hold on; plot(viz.musicTimeMs, viz.musicOuter, 'Color', blue);
title('The two edges of the unwound groove: one channel each'); ylabel('micrometres'); legend('inner edge (left)', 'outer edge (right)');
subplot(2, 1, 2);
plot(viz.musicTimeMs, viz.musicLeft, 'Color', red); hold on; plot(viz.musicTimeMs, viz.musicRight, 'Color', blue);
title('After speed, playback curve and noise filter: the sound'); xlabel('time (ms)'); ylabel('audio');
saveFigure(outFolder, 'step6_sound');

% --- 7. Signal, noise and the filter -------------------------------------------
figure('Color', 'w', 'Position', [100 100 1100 520]);
subplot(2, 1, 1);
loglog(viz.spectrumHz, viz.spectrumTotal, 'k'); hold on; loglog(viz.spectrumHz, viz.spectrumNoise, 'Color', red);
title('Measured from odd frames against even frames'); ylabel('power'); legend('groove + noise', 'noise alone');
subplot(2, 1, 2);
semilogx(viz.spectrumHz, viz.filterGain, 'Color', blue, 'LineWidth', 1.5); ylim([0 1.05]);
title('Filter factor per frequency: 1 keeps, 0 discards'); xlabel('frequency (Hz)'); ylabel('gain');
saveFigure(outFolder, 'step7_filter');


function saveFigure(folder, name)
print(gcf, fullfile(folder, [name '.png']), '-dpng', '-r200');
end
