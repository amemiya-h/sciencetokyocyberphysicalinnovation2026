function shift = pairShift(a, b, scale, cfg)
%PAIRSHIFT  How far the disc moved along the grooves between two frames.
%
%   shift = groove.mosaic.pairShift(a, b, scale, cfg)
%
%   a, b    prepared frames (see groove.mosaic.prepareFrame), a earlier
%   scale   function giving the relative shift at a row (1 at the centre
%           row); grooves further from the spindle move further
%
%   The audio wiggle of each groove is its fingerprint. Every groove of
%   frame a is correlated with its counterpart in frame b, and the
%   correlations of all grooves are added up, each stretched by the scale of
%   its row, so quiet grooves borrow certainty from loud ones.
%
%   shift fields
%     centre   shift at the centre row, in pixels (positive: content moved
%              toward higher columns)
%     score    mean correlation at that shift, 0..1
%     grooveA, grooveB   indices of the matched grooves in each frame
%     lag      each matched groove's own best shift (NaN if unclear)
%     weight   how clear that groove's match was
%     radial   how far the grooves moved across the frame, in pixels

width  = a.width;
lagMin = -round(cfg.mosaic.maxBackward * width);
lagMax =  round(cfg.mosaic.maxForward  * width);
reach  = max(abs(lagMin), lagMax);
lags   = lagMin - ceil(0.1 * reach) - 8 : lagMax + ceil(0.1 * reach) + 8;   % room for the row scale
candidates = (lagMin:0.5:lagMax).';

% Grooves are matched by position. The frame may have slipped sideways by
% a fraction of the pitch, and which neighbour is "the same groove" is then
% settled by the fingerprints: try the nearest and one pitch either side.
pitch = median(diff(a.rows));
nearest  = nearestIndex(b.rows, a.rows);
fraction = median(b.rows(nearest) - a.rows);

best.score = -Inf;
for wholeGrooves = [-1, 0, 1]
    target  = a.rows + fraction + wholeGrooves * pitch;
    partner = nearestIndex(b.rows, target);
    matched = abs(b.rows(partner) - target) < pitch / 4;
    grooveA = find(matched);
    grooveB = partner(matched);
    if numel(grooveA) < 10
        continue
    end
    correlation = crossCorrelate(a, b, grooveA, grooveB, lags);
    rowScale = scale(a.rows(grooveA));

    % Sum over grooves, reading each groove's correlation at its own lag:
    % candidate shift c means lag c * rowScale(g) for groove g. All
    % candidates and grooves at once, by linear interpolation.
    at    = candidates * rowScale(:).' - lags(1) + 1;       % numCandidates x numGrooves
    below = floor(at);
    part  = at - below;
    grooveIndex = repmat(1:numel(grooveA), numel(candidates), 1);
    numGrooves  = numel(grooveA);
    lower = correlation(grooveIndex + (below - 1) * numGrooves);
    upper = correlation(grooveIndex + below * numGrooves);
    total = sum((1 - part) .* lower + part .* upper, 2);
    [score, at] = max(total);
    if score / numel(grooveA) > best.score
        best.score   = score / numel(grooveA);
        best.centre  = candidates(at);
        best.grooveA = grooveA;
        best.grooveB = grooveB;
        best.correlation = correlation;
        best.rowScale = rowScale;
        best.radial  = fraction + wholeGrooves * pitch;
    end
end

% Each groove's own peak near the common answer, to sub-pixel precision.
numMatched = numel(best.grooveA);
lag    = nan(numMatched, 1);
weight = zeros(numMatched, 1);
for g = 1:numMatched
    expected = round(best.centre * best.rowScale(g)) - lags(1) + 1;
    around   = best.correlation(g, expected - 4:expected + 4);
    [peak, at] = max(around);
    if at > 1 && at < 9
        curvature = around(at - 1) - 2*around(at) + around(at + 1);
        if curvature < 0
            lag(g) = lags(expected - 5 + at) + 0.5 * (around(at - 1) - around(at + 1)) / curvature;
            weight(g) = max(peak, 0);
        end
    end
end

shift.centre  = best.centre;
shift.score   = best.score;
shift.grooveA = best.grooveA;
shift.grooveB = best.grooveB;
shift.lag     = lag;
shift.weight  = weight;
shift.radial  = best.radial;
end


function index = nearestIndex(values, targets)
[~, index] = min(abs(values(:).' - targets(:)), [], 2);
end


function correlation = crossCorrelate(a, b, grooveA, grooveB, lags)
% correlation(g, k): how well groove g of frame a, shifted by lags(k),
% matches its partner in frame b. Normalised to 1 for identical content.
n = size(a.spectrum, 2);
product = real(ifft(conj(a.spectrum(grooveA, :)) .* b.spectrum(grooveB, :), [], 2));
correlation = product(:, mod(lags, n) + 1);
correlation = correlation ./ sqrt(a.energy(grooveA) .* b.energy(grooveB) + 1e-9);
end
