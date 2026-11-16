function ring = unwindMosaic(mosaic, period, stepSign, cfg)
%UNWINDMOSAIC  Lay the mosaic's groove bands end to end as one groove.
%
%   ring = groove.mosaic.unwindMosaic(mosaic, period, stepSign, cfg)
%
%   Same idea as groove.track.unwindRing: each band contributes exactly one
%   revolution, then the next band takes over. Here the length of a
%   revolution comes from groove.mosaic.findRevolution instead of from a
%   stepper count.
%
%   ring has the fields groove.audio.edgesToAudio and
%   groove.track.groovePosition expect (inner, outer in mm, samplesPerRev,
%   sampleRate, numTurns, filledFraction). The sample rate is whatever one
%   revolution of bins amounts to and is generally not a round number;
%   use groove.audio.resampleTo afterwards.

% Sliding each frame onto the mosaic removed its shake, but also any slow
% real change of groove radius, and left the mosaic's radial reference
% free to wander. The slow part of the slides is put back, so that slow
% groove position is what the camera saw: image row, averaged over shake.
slow = slowFrameOffset(mosaic, cfg);
mosaic.top    = mosaic.top    + slow;
mosaic.bottom = mosaic.bottom + slow;

seen    = ~isnan(mosaic.top);
used    = find(sum(seen, 2) > 3000);
covered = find(sum(seen(used, :), 1) >= numel(used) / 2);
first   = covered(1) + floor((covered(end) - covered(1) + 1 - period) / 2);
turn    = first : first + period - 1;

% Bands seen for the whole revolution mark where the usable stretch starts
% and ends. Every band between them is used, even one with holes: a hole is
% bridged and costs a moment of sound, whereas leaving the band out would
% cut the groove there and lose everything beyond it.
coverage = mean(seen(:, turn), 2);
complete = find(coverage >= cfg.track.minCoverage).';
if isempty(complete)
    error('groove:mosaic:noCompleteTurn', ...
        'No groove band was seen for a whole revolution. Check focus, contrast and the detection limits.');
end
tracks = complete(1):complete(end);
% A band number that was never seen at all is not a groove: where the
% grooves are cut far apart (between songs), the numbering can skip one.
% Such a number is left out and its neighbours follow each other directly.
tracks = tracks(coverage(tracks) >= 0.05);
holed  = tracks(coverage(tracks) < cfg.track.minCoverage);
for t = holed
    warning('groove:mosaic:holedBand', ...
        'Groove turn %d of %d was only seen for %.0f%% of the revolution; the rest is bridged (about %.2f s of sound missing).', ...
        find(tracks == t), numel(tracks), 100 * coverage(t), (1 - coverage(t)) * 60 / cfg.record.rpm);
end
if stepSign < 0
    tracks = fliplr(tracks);            % order in which moving forward visits them
end

% The same groove point, seen a revolution apart in neighbouring bands,
% should sit at the same row. If the disc crept sideways during the scan
% it does not. Measure the creep in the overlap and spread it evenly over
% the revolution (the best that can be done without knowing when it crept).
overlapLength = min(covered(end) - turn(end), round(2000 / cfg.camera.pixelSizeUm));   % just past the seam
overlap = turn(1) + (1:overlapLength);
centre  = (mosaic.top + mosaic.bottom) / 2;
drift   = zeros(1, numel(tracks) - 1);
closure = struct('liveliness', -1, 'lateUm', [], 'earlyUm', []);
for n = 1:numel(tracks) - 1
    late  = centre(tracks(n),     overlap + period);
    early = centre(tracks(n + 1), overlap);
    both  = ~isnan(late) & ~isnan(early);
    if sum(both) >= 10
        drift(n) = median(late(both) - early(both));
        % Keep the liveliest overlap as an illustration of the closure:
        % the same stretch of groove, seen one revolution apart.
        lateWiggle  = late  - mean(late(both));
        earlyWiggle = early - mean(early(both));
        liveliness  = mean(earlyWiggle(both).^2);
        if all(both) && liveliness > closure.liveliness
            closure.liveliness = liveliness;
            closure.lateUm  = double(lateWiggle)  * cfg.camera.pixelSizeUm;
            closure.earlyUm = double(earlyWiggle) * cfg.camera.pixelSizeUm;
        end
    else
        drift(n) = NaN;         % a hole at this seam: nothing to compare
    end
end
ramp = median(drift(~isnan(drift))) * (0:period - 1) / period;

top    = zeros(numel(tracks), period);
bottom = zeros(numel(tracks), period);
missing = false(numel(tracks), period);
seamStep = zeros(1, numel(tracks) - 1);
for n = 1:numel(tracks)
    missing(n, :) = isnan(mosaic.top(tracks(n), turn));
    top(n, :)    = groove.util.fillGaps(double(mosaic.top(tracks(n), turn)))    - ramp;
    bottom(n, :) = groove.util.fillGaps(double(mosaic.bottom(tracks(n), turn))) - ramp;
    if n > 1        % close the small step left at the seam
        before = (top(n - 1, end) + bottom(n - 1, end)) / 2;
        slope  = before - (top(n - 1, end - 1) + bottom(n - 1, end - 1)) / 2;
        step   = before + slope - (top(n, 1) + bottom(n, 1)) / 2;
        if isnan(step), step = 0; end
        seamStep(n - 1) = step - sum(seamStep(1:n - 2));   % this seam's own share
        top(n, :)    = top(n, :) + step;
        bottom(n, :) = bottom(n, :) + step;
    end
end
top    = groove.util.fillGaps(reshape(top.', 1, []));       % nothing undefined may reach the audio
bottom = groove.util.fillGaps(reshape(bottom.', 1, []));

% Rows to radius. One revolution of bins is the circumference at the
% image centre row, which gives the radius there without knowing the rig.
pixelMm = cfg.camera.pixelSizeUm * 1e-3;
centreRadius = period / (2*pi);                         % pixels
centreRow    = (cfg.frameHeight + 1) / 2;
if strcmpi(cfg.camera.spindleDirection, 'down')
    inner = (centreRadius - (bottom - centreRow)) * pixelMm;
    outer = (centreRadius - (top    - centreRow)) * pixelMm;
    forwardIsInward = stepSign > 0;
else
    inner = (centreRadius + (top    - centreRow)) * pixelMm;
    outer = (centreRadius + (bottom - centreRow)) * pixelMm;
    forwardIsInward = stepSign < 0;
end

% Playback runs inward (unless the record says otherwise).
if forwardIsInward ~= cfg.record.playsInward
    inner = fliplr(inner);
    outer = fliplr(outer);
end

ring.inner = inner;
ring.outer = outer;
ring.samplesPerRev  = period;
ring.sampleRate     = period / (60 / cfg.record.rpm);
ring.numTurns       = numel(tracks);
ring.filledFraction = mean(missing(:));
bridged = reshape(missing.', 1, []);        % which samples are bridged, not measured
if forwardIsInward ~= cfg.record.playsInward
    bridged = fliplr(bridged);
end
ring.bridged = bridged;
ring.seamDriftPx    = drift;
ring.seamStepPx     = seamStep;
ring.closureExample = closure;
ring.holedTurns     = numel(holed);
end


function slow = slowFrameOffset(mosaic, cfg)
% Frame slides smoothed along the groove, one value per mosaic bin.
sigma = cfg.mosaic.shakeLengthUm / cfg.camera.pixelSizeUm / 2;
numBins = size(mosaic.top, 2);
coarse  = 1:100:numBins;
framesAt = mosaic.framePosition + mosaic.binOffset;
smoothed = zeros(size(coarse));
for n = 1:numel(coarse)
    kernel = exp(-0.5 * ((framesAt - coarse(n)) / sigma).^2);
    smoothed(n) = sum(kernel .* mosaic.frameOffset) / max(sum(kernel), 1e-9);
end
slow = single(interp1(coarse, smoothed, 1:numBins, 'linear', 'extrap'));
end
