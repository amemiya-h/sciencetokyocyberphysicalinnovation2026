%% Keyence video -> one ring of frames for retrieve_keyence_ring.m
% The rig turns the disc under the microscope while the VHX records a
% video. This script picks frames covering exactly one revolution, with
% enough overlap and in the best focus available, and writes them
% (grey PNG) plus meta.mat to data/keyence_recording/<video name>/.
% Then run retrieve_keyence_ring.m with dataset set to that folder.
%
%   1. Read the video once (a few minutes for 2 GB) and measure the shift
%      between consecutive frames and against the first frame
%      (cached in motion.mat, so later runs skip this).
%   2. Find where frame 1's content comes back = one revolution, which
%      also gives the rig radius (Rcam) without measuring it.
%   3. Pick the frames, read the video again and save them, mirrored left
%      to right so that playing time runs to the right as in the
%      simulation (a straight camera view of a record turning clockwise
%      has the music running to the left).
%
% Assumes: grooves left-right along the long side, outer edge of the
% record at the top, the disc turned in its playing direction (image
% content moving to the right). Lengths in micrometres (um).

clear; close all; clc;

videoFile = fullfile(project_root(), 'data', 'keyence_recording', '20261027_184833.avi');
magnification = 50;          % VHX zoom setting (pixel = 148.8/mag um); check!
rpm = 100/3;
mirrored = false;            % true if the VHX shows a mirror image
selOpts = struct('minOverlap', 0.2, 'maxOverlap', 0.5);

[~, name] = fileparts(videoFile);
outDir = fullfile(fileparts(videoFile), name);
if ~exist(outDir, 'dir'), mkdir(outDir); end
cam.pixel = 148.8 / magnification;

%% 1. Motion through the video

tic;
mot = scan_video_motion(videoFile, struct('cacheFile', fullfile(outDir, 'motion.mat')));
cam.imageSize = [mot.height, mot.width];
fprintf('%d frames at %.2f fps; disc moved %.0f px (%.1f mm) along the grooves (%.0f s)\n', ...
    mot.n, mot.fps, sum(mot.dx), sum(mot.dx) * cam.pixel / 1000, toc);
if sum(mot.dx) < 0
    error(['The image content moves to the left: the disc was turned against ' ...
           'its playing direction (or the view is mirrored). Set mirrored = true ' ...
           'if the view is mirrored; otherwise reverse the frame order.']);
end

%% 2. One revolution

sel = select_ring_frames(mot, selOpts);
if ~sel.ring
    error('Frame 1 never comes back: the video does not cover a full revolution.');
end
Rcam = sel.revPx * cam.pixel / (2*pi);
N = numel(sel.frames);
fprintf(['One revolution = %.0f px (frame %d matches frame 1): rig radius %.1f mm, ' ...
         'motion skew %.2f deg, radial creep %.1f um per revolution\n'], ...
    sel.revPx, sel.loopFrame, Rcam / 1000, rad2deg(sel.skew), sel.driftPx * cam.pixel);
fprintf('%d frames picked; step %.0f..%.0f px; focus at the picks %.1f (all frames: median %.1f)\n', ...
    N, min(sel.stepPx), max(sel.stepPx), median(sel.sharp), median(mot.sharp));

figure('Name', 'Video motion');
X = cumsum(mot.dx);
subplot(2,1,1);
plot((1:mot.n)/mot.fps, X * cam.pixel / 1000);  hold on;
plot((sel.frames)/mot.fps, sel.X * cam.pixel / 1000, 'r.');
xlabel('time (s)');  ylabel('position along groove (mm)');
legend('disc', 'picked frames', 'Location', 'northwest');
subplot(2,1,2);
plot((1:mot.n)/mot.fps, mot.sharp);  hold on;
plot((sel.frames)/mot.fps, sel.sharp, 'r.');
xlabel('time (s)');  ylabel('focus (mean gradient across grooves)');

%% 3. Save the picked frames

v = VideoReader(videoFile);
k = 0;  j = 1;
tic;
while hasFrame(v) && j <= N
    I = readFrame(v);
    k = k + 1;
    if k ~= sel.frames(j), continue; end
    g = uint8(mean(double(I), 3));
    if ~mirrored, g = fliplr(g); end
    imwrite(g, fullfile(outDir, sprintf('frame_%04d.png', j)));
    j = j + 1;
end
fprintf('Saved %d frames to %s (%.0f s)\n', j - 1, outDir, toc);

% Groove width and spacing from the first frame
I1 = double(imread(fullfile(outDir, 'frame_0001.png'))) / 255;
t = detect_grooves_frame(I1, cam, struct('expectedWidth', 65, 'widthTol', 0.5));
grooveWidth = median((t.inner(:) - t.outer(:)) * cam.pixel, 'omitnan');
c = median((t.outer + t.inner) / 2, 2, 'omitnan');
pitch = median(diff(sort(c))) * cam.pixel;
fprintf('Groove width %.1f um, spacing %.1f um\n', grooveWidth, pitch);

nominalStep = sel.stepPx * 2*pi / sel.revPx;      % rad, per pair (last: N -> 1)
% expected radial shift of the grooves from each frame to the next (um):
% content moving down the image = smaller radius
offset0 = -sel.radialPx * cam.pixel;
regOpts = struct('search', 0.03, 'offset0', offset0);
ring = true;
frames = sel.frames;
save(fullfile(outDir, 'meta.mat'), 'cam', 'Rcam', 'nominalStep', 'ring', ...
     'grooveWidth', 'pitch', 'rpm', 'regOpts', 'frames', 'videoFile', 'magnification');
