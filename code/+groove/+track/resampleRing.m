function ring = resampleRing(ring, sampleRate, cfg)
%RESAMPLERING  Give a ring a chosen number of samples per revolution.
%
%   ring = groove.track.resampleRing(ring, cfg.audio.sampleRate, cfg)
%
%   A freehand ring has as many samples per revolution as its circumference
%   had pixels, so rings from different radii never match. Rings must
%   share one rate before groove.track.joinRings can splice them.
%   Linear interpolation; at the rates involved it costs a fraction of a
%   decibel at the top of the usable band.

perRev = round(sampleRate * 60 / cfg.record.rpm);
if perRev == ring.samplesPerRev
    return
end
numOld = numel(ring.inner);
numNew = round(numOld * perRev / ring.samplesPerRev);
at = 1 + (0:numNew - 1) * (ring.samplesPerRev / perRev);
at = min(at, numOld);
ring.inner = interp1(1:numOld, ring.inner, at, 'linear');
ring.outer = interp1(1:numOld, ring.outer, at, 'linear');
if isfield(ring, 'bridged')
    ring.bridged = ring.bridged(round(at));
end
ring.samplesPerRev = perRev;
ring.sampleRate    = perRev / (60 / cfg.record.rpm);
end
