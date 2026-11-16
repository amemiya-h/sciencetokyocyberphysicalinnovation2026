function ring = unwindRing(tracks, cfg)
%UNWINDRING  Lay the groove turns of one revolution end to end.
%
%   ring = groove.track.unwindRing(tracks, cfg)
%
%   During one revolution the camera sees many groove bands at once. Each
%   band is one turn of the spiral, and after exactly one revolution a band
%   has moved to where its inner neighbour started. So the continuous groove
%   is: outermost band, then the next one in, and so on, each cut to exactly
%   one revolution. The stepper makes "exactly one revolution" a known
%   number of samples, so no matching is needed here.
%
%   ring fields
%     inner, outer   edge radii in mm along the groove      (1 x numSamples)
%     samplesPerRev  samples in one revolution
%     sampleRate     audio sample rate the samples correspond to
%     numTurns       complete groove turns in this ring
%     filledFraction share of samples that had to be interpolated

perRev = tracks.samplesPerRev;
if size(tracks.inner, 2) < perRev
    error('groove:track:shortScan', ...
        'The scan holds %d samples but one revolution needs %d. Film a little more than one full turn.', ...
        size(tracks.inner, 2), perRev);
end

inner = tracks.inner(:, 1:perRev);
outer = tracks.outer(:, 1:perRev);

% Keep bands that were visible for the whole revolution.
coverage = mean(~isnan(inner), 2);
complete = coverage >= cfg.track.minCoverage;
if ~any(complete)
    error('groove:track:noCompleteTurn', ...
        'No groove was followed for a whole revolution. Check focus, contrast and the detection limits.');
end
missing = isnan(inner(complete, :));
inner = groove.util.fillGaps(inner(complete, :));
outer = groove.util.fillGaps(outer(complete, :));

% Playback runs from the outside inward.
[~, order] = sort(inner(:, 1), 'descend');
inner = inner(order, :);
outer = outer(order, :);
missing = missing(order, :);

% Neighbouring bands must really be consecutive turns: the end of one has
% to meet the start of the next. Keep the longest unbroken run.
centre = (inner + outer) / 2;
meets  = abs(centre(1:end-1, end) - centre(2:end, 1)) <= cfg.track.gateUm * 1e-3;
[firstTurn, lastTurn] = longestRun(meets);
if lastTurn - firstTurn + 1 < size(inner, 1)
    warning('groove:track:brokenRing', ...
        'Only %d of %d complete turns are consecutive; the rest are dropped.', ...
        lastTurn - firstTurn + 1, size(inner, 1));
end
turns = firstTurn:lastTurn;

ring.inner = reshape(inner(turns, :).', 1, []);
ring.outer = reshape(outer(turns, :).', 1, []);
ring.samplesPerRev  = perRev;
ring.sampleRate     = cfg.audio.sampleRate;
ring.numTurns       = numel(turns);
ring.filledFraction = mean(reshape(missing(turns, :), 1, []));
end


function [first, last] = longestRun(linked)
% linked(k) says item k connects to item k+1. Return the longest chain.
first = 1; last = 1;
start = 1;
for k = 1:numel(linked) + 1
    if k > numel(linked) || ~linked(k)
        if k - start > last - first
            first = start; last = k;
        end
        start = k + 1;
    end
end
end
