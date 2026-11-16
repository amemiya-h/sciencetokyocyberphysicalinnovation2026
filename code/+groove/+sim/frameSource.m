function source = frameSource(disc, cfg, frameSize, numFrames, startAngle)
%FRAMESOURCE  Render microscope frames of a synthetic disc.
%
%   source = groove.sim.frameSource(disc, cfg, frameSize, numFrames, startAngle)
%
%   disc        from groove.sim.syntheticDisc
%   cfg         the same configuration the analysis will use; the camera,
%               turntable and ring settings define the virtual setup
%   frameSize   [rows cols] of the virtual camera
%   numFrames   frames to make available
%   startAngle  disc angle (radians) under the camera in the first frame;
%               default 0. The analysis is never told this value.
%
%   Frames show bright land and dark grooves with slightly blurred edges.
%   Groove curvature inside the frame is rendered faithfully.

if nargin < 5
    startAngle = 0;
end
source.numFrames = numFrames;
source.frameSize = frameSize;
source.read      = @(frameIndex) renderFrame(disc, cfg, frameSize, frameIndex, startAngle);
end


function frame = renderFrame(disc, cfg, frameSize, frameIndex, startAngle)
pixelMm = cfg.camera.pixelSizeUm * 1e-3;
rows    = (1:frameSize(1)).' - (frameSize(1) + 1) / 2;
columns = (1:frameSize(2))   - (frameSize(2) + 1) / 2;

rowSign    = 1 - 2 * strcmpi(cfg.camera.spindleDirection, 'down');
motionSign = 2 * strcmpi(cfg.camera.motionDirection, 'right') - 1;
turnSign   = 2 * cfg.turntable.playbackDirection - 1;

% Position of every pixel on the disc, in polar coordinates about the axis.
alongRadius = cfg.ring.radiusMm + rowSign * rows * pixelMm;
acrossMm    = columns * pixelMm;
radius = sqrt(alongRadius.^2 + acrossMm.^2);
frameAngle = 2*pi / cfg.turntable.framesPerRev;
angle  = startAngle + turnSign * ((frameIndex - 1) * frameAngle ...
         - motionSign * atan2(acrossMm, alongRadius));

% Which turn of the spiral is nearest to each pixel?
pitchMm = disc.pitchUm * 1e-3;
wobble  = disc.eccentricityUm * 1e-3 * cos(angle);
turn = round((disc.startRadiusMm + wobble - radius) / pitchMm - angle / (2*pi));
[inner, outer] = groove.sim.grooveEdges(disc, angle + 2*pi*turn);

% Depth inside the groove in pixels, turned into a dark band whose edges
% are blurred over two pixels, roughly what the optics would do.
depth = min(radius - inner, outer - radius) / pixelMm;
darkness = min(max(depth / 2 + 0.5, 0), 1);
frame = 0.9 - 0.8 * darkness;
end
