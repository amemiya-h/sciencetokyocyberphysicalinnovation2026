function tr = track_groove_edges(I, x, opts)
%TRACK_GROOVE_EDGES  Find the left and right groove edge in every row.
%   tr = TRACK_GROOVE_EDGES(I, x, opts) scans the image row by row. In each
%   row, edge candidates are local maxima of the intensity-gradient
%   magnitude, refined to sub-pixel position by fitting a parabola
%   through the peak and its two neighbours. Every left/right candidate
%   pair is scored on edge strength,
%   closeness to the expected width and closeness to the previous row's
%   centre, and the best pair is kept. Rows with no acceptable pair stay
%   NaN. Individual edges are NOT required to be continuous between rows;
%   that is left to post-processing (see centreline_to_audio).
%
%   Inputs
%     I     nRows x nCols intensity image, rows along the groove
%     x     1 x nCols positions across the groove (um)
%     opts  struct with fields
%       expectedWidth   groove width at the surface (um)
%       widthTolerance  accepted widths are expectedWidth*(1 -/+ this)
%       trackingWindow  max centre shift from the last accepted row (um)
%       profileSmooth   Gaussian smoothing window per row (samples)
%       startCentre     centre position used to start tracking (um)
%       feature         'step' (default): edges are brightness steps, as
%                       under coaxial light; 'ridge': edges are thin
%                       bright lines, as under low side or ring light
%
%   Output (struct tr), each nRows x 1, NaN where no pair was accepted
%     left, right, centre   edge and midpoint positions (um)

% Weights of the two penalties relative to edge strength (0..1)
widthWeight = 0.5;
trackingWeight = 0.5;

dx = x(2) - x(1);
nRows = size(I, 1);
tr.left = nan(nRows, 1);
tr.right = nan(nRows, 1);
tr.centre = nan(nRows, 1);

ridge = isfield(opts, 'feature') && strcmp(opts.feature, 'ridge');
minWidth = (1 - opts.widthTolerance) * opts.expectedWidth;
maxWidth = (1 + opts.widthTolerance) * opts.expectedWidth;
previousCentre = opts.startCentre;

for r = 1:nRows
    % Candidate edges: local maxima of the gradient magnitude
    profile = smoothdata(I(r, :), 'gaussian', opts.profileSmooth);
    if ridge
        edgeStrength = profile;
    else
        edgeStrength = abs(gradient(profile, dx));
    end
    idx = find(islocalmax(edgeStrength));
    idx = idx(idx > 1 & idx < numel(edgeStrength));
    e0 = edgeStrength(idx);
    em = edgeStrength(idx - 1);
    ep = edgeStrength(idx + 1);
    curv = em - 2*e0 + ep;
    shift = zeros(size(idx));
    ok = curv < 0;
    shift(ok) = min(max(0.5 * (em(ok) - ep(ok)) ./ curv(ok), -0.5), 0.5);
    xCand = x(idx) + shift * dx;
    sCand = e0 / (max(edgeStrength) + eps);

    % All left/right pairs either side of the previous centre
    [iL, iR] = ndgrid(find(xCand < previousCentre), ...
                      find(xCand > previousCentre));
    xl = xCand(iL);
    xr = xCand(iR);
    width = xr - xl;
    centre = (xl + xr) / 2;

    % Higher score is better
    score = (sCand(iL) + sCand(iR)) / 2 ...
        - widthWeight * abs(width - opts.expectedWidth) / opts.expectedWidth ...
        - trackingWeight * abs(centre - previousCentre) / opts.trackingWindow;

    implausible = width < minWidth | width > maxWidth ...
        | abs(centre - previousCentre) > opts.trackingWindow;
    score(implausible) = -Inf;

    [best, k] = max(score(:));
    if isempty(best) || isinf(best)
        continue;   % no acceptable pair: leave NaN, keep previous centre
    end

    tr.left(r) = xl(k);
    tr.right(r) = xr(k);
    tr.centre(r) = centre(k);
    previousCentre = centre(k);
end
end
