function [mosaic, rejectedFraction] = rejectDisagreement(mosaic, cfg)
%REJECTDISAGREEMENT  Drop samples where odd and even frames tell different stories.
%
%   [mosaic, rejectedFraction] = groove.mosaic.rejectDisagreement(mosaic, cfg)
%
%   The groove is the same whichever frames it is read from. Dust that sat
%   in some frames, or an edge misread in one view, is not. So wherever
%   the mosaic built from odd frames and the one built from even frames
%   differ by far more than the noise allows, the sample is marked unseen;
%   unwinding then bridges it from its neighbours. This catches clicks too
%   small to break the speed limit in groove.audio.declick.
%
%   The limit is cfg.mosaic.clickSigma times the typical disagreement
%   nearby (about 2000 samples either side).

limit = cfg.mosaic.clickSigma;
numRejected = 0;
numSeen = 0;
for t = 1:size(mosaic.top, 1)
    weightA = squeeze(mosaic.halfWeight(1, t, :)).';
    weightB = squeeze(mosaic.halfWeight(2, t, :)).';
    both = weightA > 0.2 & weightB > 0.2;
    if sum(both) < 1000
        continue
    end
    bad = false(size(both));
    for edge = 1:2
        if edge == 1, sums = mosaic.halfTop; else, sums = mosaic.halfBottom; end
        a = double(squeeze(sums(1, t, :)).') ./ max(double(weightA), 1e-6);
        b = double(squeeze(sums(2, t, :)).') ./ max(double(weightB), 1e-6);
        difference = (a - b) .* both;
        % The typical disagreement is judged locally: in loud passages the
        % two halves differ more (a small misalignment times a steep
        % groove), and that must not be mistaken for clicks.
        window  = ones(1, 2001);
        local   = 1.25 * conv(abs(difference), window, 'same') ./ max(conv(double(both), window, 'same'), 1);
        overall = 1.4826 * median(abs(difference(both)));
        typical = max(local, 0.5 * overall);
        bad = bad | abs(difference) > limit * typical;
    end
    bad = conv(double(bad), ones(1, 7), 'same') > 0;       % and a few samples either side
    bad = bad & ~isnan(mosaic.top(t, :));
    mosaic.top(t, bad)    = NaN;
    mosaic.bottom(t, bad) = NaN;
    numRejected = numRejected + sum(bad);
    numSeen = numSeen + sum(both);
end
rejectedFraction = numRejected / max(numSeen, 1);
end
