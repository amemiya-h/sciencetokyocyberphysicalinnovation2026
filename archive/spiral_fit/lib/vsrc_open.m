function vs = vsrc_open(file)
%VSRC_OPEN  Open a frame source: a video file, or a -v7 .mat with frames F.
%   vs = VSRC_OPEN(file). Use VSRC_READ to read frames in order and
%   VSRC_FRAME to read one frame by index. The .mat form (variables F, an
%   h x w x K uint8 array, and fps) is for small synthetic tests.
vs = struct('file', file, 'kind', '', 'vr', [], 'F', [], 'fps', NaN, ...
    'W', 0, 'H', 0, 'next', 1);
[~, ~, ext] = fileparts(file);
if strcmpi(ext, '.mat')
    D = load(file, 'F', 'fps');
    vs.kind = 'mat'; vs.F = D.F; vs.fps = D.fps;
    vs.H = size(D.F, 1); vs.W = size(D.F, 2); vs.K = size(D.F, 3);
else
    vs.kind = 'video';
    vs.vr = VideoReader(file);
    vs.fps = vs.vr.FrameRate; vs.W = vs.vr.Width; vs.H = vs.vr.Height;
    vs.K = round(vs.vr.Duration * vs.fps);
end
end
