function geo = geometry(cfg, source)
%GEOMETRY  Work out which image columns feed which output sample.
%
%   geo = groove.scan.geometry(cfg, source)
%
%   The scan is resampled onto a uniform grid of disc angle. Because the
%   record was cut at constant angular speed, one step of that grid is one
%   audio sample. Each grid sample ("column") is taken from the frame whose
%   centre passed closest to it, from the few pixel columns it covers.
%
%   geo fields
%     samplesPerRev  grid samples in one revolution
%     numColumns     grid samples available in this video
%     frameOf        frame that supplies each column          (1 x numColumns)
%     leftEdge       where each column's slice of image starts (1 x numColumns)
%     rightEdge      and ends, in fractional pixel coordinates (1 x numColumns)
%     sagittaMm      curvature correction to add to radii     (1 x numColumns)
%     pixelMm        pixel size in mm
%     centreRow      image row that sits at cfg.ring.radiusMm
%     rowSign        +1 if radius grows with row index, -1 otherwise

pixelMm = cfg.camera.pixelSizeUm * 1e-3;
radius  = cfg.ring.radiusMm;
height  = source.frameSize(1);
width   = source.frameSize(2);

samplesPerRev = round(cfg.audio.sampleRate * 60 / cfg.record.rpm);
sampleAngle   = 2*pi / samplesPerRev;               % angle of one grid step
frameAngle    = 2*pi / cfg.turntable.framesPerRev;  % disc turn between frames

% Frame f is centred on disc angle (f-1)*frameAngle. Keep every grid sample
% that lies within half a frame step of some frame centre.
numColumns = floor((source.numFrames - 0.5) * frameAngle / sampleAngle);
angle      = ((1:numColumns) - 0.5) * sampleAngle;
frameOf    = min(round(angle / frameAngle) + 1, source.numFrames);

% Where each sample sits in its frame, in pixels from the centre column.
% Material that has already passed the centre lies further along the
% direction of motion, hence the minus sign.
motionSign  = directionSign(cfg.camera.motionDirection, 'right', 'left');
angleOffset = angle - (frameOf - 1) * frameAngle;
pixelsPerRadian = radius / pixelMm;
centreColumn = (width + 1) / 2;
middle    = centreColumn - motionSign * angleOffset * pixelsPerRadian;
halfWidth = sampleAngle * pixelsPerRadian / 2;

leftEdge  = middle - halfWidth;     % in pixel units, may be fractional
rightEdge = middle + halfWidth;

travelPixels = frameAngle * pixelsPerRadian;
if any(leftEdge < 0.5) || any(rightEdge > width + 0.5)
    error('groove:scan:frameTooNarrow', ...
        ['The disc moves %.0f pixels between frames but the frame is only ' ...
         '%d pixels wide. Turn the disc slower or raise the frame rate.'], ...
        travelPixels, width);
end

% A straight image column cuts across the curved groove. A point x off the
% centre column lies at a radius larger by x^2 / (2 r); add that back.
offsetMm  = (middle - centreColumn) * pixelMm;
sagittaMm = offsetMm.^2 / (2 * radius);

geo.samplesPerRev = samplesPerRev;
geo.numColumns    = numColumns;
geo.frameOf       = frameOf;
geo.leftEdge      = leftEdge;
geo.rightEdge     = rightEdge;
geo.sagittaMm     = sagittaMm;
geo.pixelMm       = pixelMm;
geo.centreRow     = (height + 1) / 2;
geo.rowSign       = -directionSign(cfg.camera.spindleDirection, 'down', 'up');
end


function s = directionSign(value, positiveName, negativeName)
if strcmpi(value, positiveName)
    s = 1;
elseif strcmpi(value, negativeName)
    s = -1;
else
    error('groove:scan:badDirection', ...
        'Expected ''%s'' or ''%s'' but got ''%s''.', positiveName, negativeName, value);
end
end
