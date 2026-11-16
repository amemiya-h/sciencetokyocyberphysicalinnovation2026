function [outDir, info] = extract_ring_frames(videoFile, opts)
%EXTRACT_RING_FRAMES  Microscope video of the turning disc -> one ring of frames.
%   [outDir, info] = EXTRACT_RING_FRAMES(videoFile, opts) picks frames
%   covering exactly one revolution, with enough overlap and in the best
%   focus available, and writes them (grey PNG, frame_0001.png ...) plus
%   meta.mat to outDir (default: a folder named after the video, next to
%   it). If outDir already holds meta.mat for this video, nothing is
%   redone (opts.redo = true forces it).
%
%   1. Read the video once (a few minutes for 2 GB) and measure the shift
%      between consecutive frames and against the first frame
%      (cached next to the video as <name>_motion.mat).
%   2. Find where frame 1's content comes back = one revolution, which
%      also gives the rig radius (Rcam) without measuring it.
%   3. Pick the frames, read the video again and save them, mirrored left
%      to right so that playing time runs to the right (a straight camera
%      view of a record turning clockwise has the music running left).
%
%   Assumes: grooves left-right along the long side, outer edge of the
%   record at the top, the disc turned in its playing direction.
%
%   opts fields (defaults in brackets)
%     magnification  VHX zoom (pixel = 148.8/mag um) [50]
%     rpm            [100/3]
%     mirrored       the VHX shows a mirror image [false]
%     minOverlap, maxOverlap   overlap between picked frames [0.2, 0.5]
%     views          frames that should see each point (more views =
%                    more averaging, less noise; overrides the overlaps).
%                    The frames then go to <video name>_v<views>/ [NaN]
%     outDir         ['']   redo [false]   plot [true]
%
%   info: the selection (see select_ring_frames) and the motion trace.

if nargin < 2, opts = struct(); end
def = struct('magnification', 50, 'rpm', 100/3, 'mirrored', false, ...
             'minOverlap', 0.2, 'maxOverlap', 0.5, 'views', NaN, 'outDir', '', 'redo', false, 'plot', true);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end
magnification = opts.magnification;  rpm = opts.rpm;  mirrored = opts.mirrored;
selOpts = struct('minOverlap', opts.minOverlap, 'maxOverlap', opts.maxOverlap, ...
                 'views', opts.views);
info = struct();

[~, name] = fileparts(videoFile);
outDir = opts.outDir;
if isempty(outDir)
    if isnan(opts.views), sub = name; else, sub = sprintf('%s_v%d', name, opts.views); end
    outDir = fullfile(fileparts(videoFile), sub);
end
if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~opts.redo && exist(fullfile(outDir, 'meta.mat'), 'file')
    m = load(fullfile(outDir, 'meta.mat'), 'videoFile', 'frames');
    if isfield(m, 'videoFile') && strcmp(m.videoFile, videoFile) && ...
            numel(dir(fullfile(outDir, 'frame_*.png'))) == numel(m.frames)
        fprintf('Frames already extracted in %s (opts.redo = true to redo)\n', outDir);
        return;
    end
end
cam.pixel = 148.8 / magnification;

%% 1. Motion through the video

tic;
mot = scan_video_motion(videoFile, struct('cacheFile', ...
    fullfile(fileparts(videoFile), [name '_motion.mat'])));   % shared by all frame sets
cam.imageSize = [mot.height, mot.width];
fprintf('%d frames at %.2f fps; disc moved %.0f px (%.1f mm) along the grooves (%.0f s)\n', ...
    mot.n, mot.fps, sum(mot.dx), sum(mot.dx) * cam.pixel / 1000, toc);
if mirrored        % a mirror image moves the other way: work as if straight
    mot.dx = -mot.dx;  mot.dxRef = -mot.dxRef;
end
if sum(mot.dx) < 0
    error(['The image content moves to the left: the disc was turned against ' ...
           'its playing direction, or the view is mirrored (opts.mirrored = true).']);
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

if opts.plot
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
end

%% 3. Save the picked frames

stale = fullfile(outDir, 'grooves.mat');           % grooves read from old frames
if exist(stale, 'file'), delete(stale); end

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
info.sel = sel;  info.mot = mot;
end
