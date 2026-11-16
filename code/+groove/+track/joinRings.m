function joined = joinRings(outerRing, innerRing, cfg)
%JOINRINGS  Splice two overlapping rings into one continuous groove.
%
%   joined = groove.track.joinRings(outerRing, innerRing, cfg)
%
%   The last turns of the outer ring and the first turns of the inner ring
%   are the same physical groove. The first turn of the inner ring is
%   searched for inside the outer ring by correlating the groove wiggle;
%   the outer ring is cut there and the inner ring appended. This also
%   absorbs any difference in starting angle between the two scans.
%
%   A constant radial offset between the rings (stage positioning error)
%   is measured in the overlap and removed from the inner ring, so groove
%   position stays continuous.

assert(outerRing.samplesPerRev == innerRing.samplesPerRev, ...
    'Both rings must use the same sample rate.');
perRev = innerRing.samplesPerRev;

% The sample-to-sample change of the groove centre: it carries the audio
% and is free of the slow spiral drift.
wiggle   = @(ring) diff((ring.inner + ring.outer) / 2);
template = wiggle(innerRing);
template = template(1:min(perRev, numel(template)));

% The radius says roughly where the inner ring begins inside the outer one;
% the correlation then only has to settle the exact sample.
[searchFirst, searchLast] = searchWindow(outerRing, innerRing, cfg.join.searchTurns);
outerWiggle = wiggle(outerRing);
[cut, score] = groove.util.findLag(outerWiggle(searchFirst:searchLast), template);
cut = cut + searchFirst - 1;
if score < cfg.join.minScore
    warning('groove:track:weakJoin', ...
        'Rings overlap with a match score of only %.2f; the join may be wrong. Check that the rings overlap by at least one full turn.', score);
end

overlap = cut:min(cut + numel(template), numel(outerRing.inner));
centreOuter = (outerRing.inner(overlap) + outerRing.outer(overlap)) / 2;
centreInner = (innerRing.inner(overlap - cut + 1) + innerRing.outer(overlap - cut + 1)) / 2;
radialOffset = median(centreOuter - centreInner);

joined = outerRing;
joined.inner = [outerRing.inner(1:cut-1), innerRing.inner + radialOffset];
joined.outer = [outerRing.outer(1:cut-1), innerRing.outer + radialOffset];
if isfield(outerRing, 'bridged') && isfield(innerRing, 'bridged')
    joined.bridged = [outerRing.bridged(1:cut-1), innerRing.bridged];
elseif isfield(joined, 'bridged')
    joined = rmfield(joined, 'bridged');
end
joined.numTurns = numel(joined.inner) / perRev;
joined.filledFraction = NaN;   % not tracked across joins
end


function [first, last] = searchWindow(outerRing, innerRing, searchTurns)
% Samples of the outer ring among which the inner ring's start is sought.
perRev = innerRing.samplesPerRev;
turnMean = @(ring, turn) mean(ring.inner((turn-1)*perRev + (1:perRev)) ...
                            + ring.outer((turn-1)*perRev + (1:perRev))) / 2;
outerMeans = arrayfun(@(turn) turnMean(outerRing, turn), 1:floor(outerRing.numTurns));
[~, matchingTurn] = min(abs(outerMeans - turnMean(innerRing, 1)));

expected = (matchingTurn - 1) * perRev + 1;
reach    = round(searchTurns * perRev);
first = max(1, expected - reach);
last  = min(numel(outerRing.inner) - 1, expected + reach + perRev);
if isinf(searchTurns)
    first = 1;
    last  = numel(outerRing.inner) - 1;
end
end
