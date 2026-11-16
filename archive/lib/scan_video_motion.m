function mot = scan_video_motion(file, opts)
%SCAN_VIDEO_MOTION  How the disc moves through a microscope video.
%   mot = SCAN_VIDEO_MOTION(file, opts) reads every frame once (a 2 GB
%   video takes a few minutes) and measures, from downsampled grey
%   images:
%     - the shift between consecutive frames (phase correlation),
%     - the shift of every frame relative to the first one, which comes
%       back after a full revolution of the disc (loop closure),
%     - a focus value: the mean brightness gradient across the grooves
%       (a warped disc drifts in and out of focus as it turns).
%   The result is cached in opts.cacheFile, if given, and reused.
%
%   opts fields (defaults in brackets)
%     scale      downsampling factor [2]
%     cacheFile  .mat file to save/reuse the result ['']
%
%   Output struct mot (shifts in full-resolution pixels, x right, y down;
%   content of frame k relative to frame k-1, or to frame 1)
%     n, fps, width, height
%     dx, dy, resp        1 x n, consecutive frames (dx(1) = 0)
%     dxRef, dyRef, respRef   1 x n, relative to frame 1
%     sharp               1 x n mean |vertical gradient| (focus)

if nargin < 2, opts = struct(); end
if ~isfield(opts, 'scale'), opts.scale = 2; end
if ~isfield(opts, 'cacheFile'), opts.cacheFile = ''; end
if ~isempty(opts.cacheFile) && exist(opts.cacheFile, 'file')
    S = load(opts.cacheFile);
    mot = S.mot;
    return;
end

v = VideoReader(file);
s = opts.scale;
h = floor(v.Height / s);  w = floor(v.Width / s);
win = hann_window(h) * hann_window(w)';
nEst = max(1, floor(v.Duration * v.FrameRate) + 5);
[dx, dy, resp, dxR, dyR, respR, sharp] = deal(nan(1, nEst));
k = 0;  Fprev = [];  Fref = [];
t0 = tic;
while hasFrame(v)
    I = readFrame(v);
    k = k + 1;
    g = grey_small(I, s, h, w);
    sharp(k) = mean(mean(abs(diff(g, 1, 1))));
    F = fft2((g - mean(g(:))) .* win);
    if k == 1
        Fref = F;
        dx(1) = 0;  dy(1) = 0;  resp(1) = 1;
        dxR(1) = 0; dyR(1) = 0; respR(1) = 1;
    else
        [dx(k), dy(k), resp(k)] = phase_correlate(Fprev, F);
        [dxR(k), dyR(k), respR(k)] = phase_correlate(Fref, F);
    end
    Fprev = F;
    if mod(k, 200) == 0
        fprintf('  scanned %d frames (%.0f s)\n', k, toc(t0));
    end
end
mot.n = k;  mot.fps = v.FrameRate;
mot.width = v.Width;  mot.height = v.Height;
mot.dx = dx(1:k) * s;   mot.dy = dy(1:k) * s;   mot.resp = resp(1:k);
mot.dxRef = dxR(1:k) * s;  mot.dyRef = dyR(1:k) * s;  mot.respRef = respR(1:k);
mot.sharp = sharp(1:k);
if ~isempty(opts.cacheFile)
    save(opts.cacheFile, 'mot');
end
end

function g = grey_small(I, s, h, w)
% Grey image averaged over s x s blocks
I = double(I);
if size(I, 3) == 3, I = mean(I, 3); end
I = I(1:h*s, 1:w*s);
g = reshape(sum(reshape(I, s, []), 1), h, w*s);          % rows
g = reshape(sum(reshape(g', s, []), 1), w, h)' / s^2;    % columns
end

function x = hann_window(n)
x = 0.5 - 0.5 * cos(2*pi*(0:n-1)' / (n-1));
end
