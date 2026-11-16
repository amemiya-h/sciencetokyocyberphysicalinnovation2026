%VISUALIZE_FORWARD_MODEL  The forward process in one figure, for slides.
%
% Music -> cutter -> groove seen from above -> what the camera records.
% The first three panels are drawn from two made-up signals, chosen to look
% different so the two edges can be told apart; the fourth is a real frame.
% Edit the marked lines. Saves results/figures/forward_model.png.

addpath(fileparts(fileparts(mfilename('fullpath'))));

% --- What to show (EDIT) -----------------------------------------------------
videoFile = 'data/keyence_recording/20261029_163032.avi';
frameNumber = 300;
outFolder = 'results/figures';
red = [0.85 0.2 0.15];  blue = [0.1 0.4 0.8];  grey = [0.55 0.55 0.55];

% Two channels, as wall movement in micrometres.
t = linspace(0, 8, 1600);                                   % ms
left  = 4.0 * sin(2*pi * 1.0 * t) .* exp(-((t - 4) / 2.5).^2);   % a 1 kHz burst
right = 3.0 * sin(2*pi * 0.35 * t + 0.6);                        % a slow tone
grooveWidth = 64;                                           % micrometres at the surface
grooveSpeed = 0.35;                                         % metres per second
along = t * grooveSpeed * 1000;                             % micrometres along the groove

% A wall at 45 degrees that moves by d along its own normal shifts its top
% edge sideways by sqrt(2) * d. The other edge does not move.
inner = -grooveWidth/2 - sqrt(2) * left;
outer =  grooveWidth/2 + sqrt(2) * right;

figure('Color', 'w', 'Position', [100 100 1200 800]);

% --- 1. The music -------------------------------------------------------------
subplot(2, 2, 1);
plot(t, left, 'Color', red); hold on; plot(t, right, 'Color', blue);
legend('left channel', 'right channel'); xlabel('time (ms)'); ylabel('wall movement (micrometres)');
title('1. Music: two channels');

% --- 2. The groove in cross-section -------------------------------------------
subplot(2, 2, 2);
[~, k] = max(left);                                         % the largest left-channel swing
drawVee(-grooveWidth/2, grooveWidth/2, grey, '--', 1.2); hold on
drawVee(inner(k), outer(k), [0 0 0], '-', 2);
plot(inner(k), 0, 'o', 'Color', red,  'MarkerFaceColor', red,  'MarkerSize', 9);
plot(outer(k), 0, 'o', 'Color', blue, 'MarkerFaceColor', blue, 'MarkerSize', 9);
text(-grooveWidth/2 - 22, -30, {'left channel', 'moves this wall'},  'Color', red,  'HorizontalAlignment', 'center');
text( grooveWidth/2 + 22, -30, {'right channel', 'moves this wall'}, 'Color', blue, 'HorizontalAlignment', 'center');
text(0, 8, 'the microscope, looking down, sees only the two top edges', 'HorizontalAlignment', 'center');
axis equal; xlim([-85 85]); ylim([-45 14]);
xlabel('across the groove (micrometres)    spindle <-    -> rim'); ylabel('depth (micrometres)');
title('2. The cutter: a V whose walls each carry one channel');

% --- 3. Seen from above --------------------------------------------------------
subplot(2, 2, 3);
across = linspace(-90, 90, 361).';
picture = 0.8 * ones(numel(across), numel(along));
picture(across > inner & across < outer) = 0.08;            % the groove is dark
imagesc(along, across, picture, [0 1]); colormap(gray); hold on
plot(along, inner, 'Color', red, 'LineWidth', 1.5); plot(along, outer, 'Color', blue, 'LineWidth', 1.5);
set(gca, 'YDir', 'normal');                                 % spindle side at the bottom, as in the frames
xlabel('along the groove (micrometres)'); ylabel('across the groove (micrometres)');
title('3. Seen from above: dark groove, two wavy edges');

% --- 4. A real frame ------------------------------------------------------------
subplot(2, 2, 4);
video = VideoReader(videoFile);
frame = groove.io.toGray(read(video, frameNumber));
rows = round(size(frame, 1) / 2) + (-120:120);
cols = round(size(frame, 2) / 2) + (-160:160);
imagesc(frame(rows, cols)); axis image off
title('4. What the camera records: many grooves, one frame');

if ~exist(outFolder, 'dir'), mkdir(outFolder); end
print(gcf, fullfile(outFolder, 'forward_model.png'), '-dpng', '-r200');


function drawVee(innerEdge, outerEdge, colour, style, width)
% A V-groove with 45-degree walls between two top edges, with some land either side.
x = [innerEdge - 25, innerEdge, (innerEdge + outerEdge) / 2, outerEdge, outerEdge + 25];
y = [0, 0, -(outerEdge - innerEdge) / 2, 0, 0];
plot(x, y, style, 'Color', colour, 'LineWidth', width);
end
