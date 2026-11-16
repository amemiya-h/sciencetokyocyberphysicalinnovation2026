function mosaic = buildMosaic(allEdges, registration, cfg, reference)
%BUILDMOSAIC  Average every view of every groove onto one long strip.
%
%   mosaic = groove.mosaic.buildMosaic(allEdges, registration, cfg)
%   mosaic = groove.mosaic.buildMosaic(allEdges, registration, cfg, reference)
%
%   Each groove band gets one row of the mosaic; columns ("bins") are
%   positions along the groove, one pixel apart at the image centre row.
%   Every frame drops the central part of each groove it sees into that
%   groove's row. Where frames overlap, their readings are averaged, which
%   is what beats the noise of a single view.
%
%   Before it is added, a frame is slid radially to agree with what is
%   already there (hand shake, a wobbling disc). Tilt and curvature of the
%   grooves in the image are the same for all frames and are removed.
%
%   reference  a mosaic from a first pass. When given, frames are aligned
%              to it instead of to the growing mosaic, and readings far
%              from it are dropped (dust). This removes the order
%              dependence of the first pass.
%
%   mosaic fields
%     top, bottom   averaged edge rows, tilt and curvature removed
%                   (numTracks x numBins, NaN where never seen)
%     weight        how much was averaged into each bin (about the number of views)
%     halfTop, halfBottom, halfWeight   the same from odd and from even
%                   frames only (2 x numTracks x numBins sums; for noise estimates)
%     firstId       groove number of the first row
%     binOffset     bin index = round(position) + binOffset
%     frameOffset   radial slide applied to each frame, pixels
%     framePosition where each frame sits along the groove, pixels
%     viewSpread    robust spread of each frame against the mosaic, pixels

if nargin < 4
    reference = [];
end
numFrames = numel(allEdges);
width     = size(allEdges{1}.top, 2);
centreColumn = (width + 1) / 2;
pixelUm   = cfg.camera.pixelSizeUm;
baseHalf  = cfg.mosaic.halfWidthUm / pixelUm;
reject    = cfg.mosaic.rejectUm / pixelUm;
position  = registration.position;
step      = abs(diff(position));

ids = cell2mat(registration.grooveId(:));
firstId   = min(ids);
numTracks = max(ids) - firstId + 1;
margin    = ceil(max(baseHalf, cfg.mosaic.widenFactor * max(step)) * 1.2) + 10;
binOffset = ceil(-min(position)) + margin;
numBins   = ceil(max(position)) + binOffset + margin;

[tilt, bend] = commonShape(allEdges, baseHalf);

sumTop    = zeros(numTracks, numBins, 'single');
sumBottom = zeros(numTracks, numBins, 'single');
weight    = zeros(numTracks, numBins, 'single');
halfTop    = zeros(2, numTracks, numBins, 'single');
halfBottom = zeros(2, numTracks, numBins, 'single');
halfWeight = zeros(2, numTracks, numBins, 'single');
frameOffset = zeros(1, numFrames);
viewSpread  = zeros(1, numFrames);

for k = 1:numFrames
    edges = allEdges{k};
    rows  = registration.rows{k};
    track = registration.grooveId{k} - firstId + 1;
    half  = max([baseHalf, cfg.mosaic.widenFactor * step(max(k - 1, 1):min(k, numFrames - 1))]);

    % Resample each groove of this frame onto the mosaic's bins.
    numGrooves = numel(rows);
    piece = cell(numGrooves, 1);
    difference = cell(numGrooves, 1);
    for g = 1:numGrooves
        if isnan(rows(g))
            continue
        end
        stretch = registration.scale(rows(g));
        bins = ceil(position(k) - half / stretch) : floor(position(k) + half / stretch);
        x    = centreColumn - (bins - position(k)) * stretch;   % image column of each bin
        away = x - centreColumn;
        shape = tilt * away + bend * away.^2;
        p.bins   = bins + binOffset;
        p.top    = sampleAt(edges.top(g, :),    x) - shape;
        p.bottom = sampleAt(edges.bottom(g, :), x) - shape;
        p.taper  = cos(pi/2 * away / half).^2;                  % fade toward the band edges
        p.track  = track(g);
        piece{g} = p;

        [known, there] = lookUp(reference, sumTop, sumBottom, weight, p);
        d = (p.top + p.bottom) / 2 - there;
        difference{g} = d(known & ~isnan(d));
    end

    % One radial slide for the whole frame.
    difference = [difference{:}];
    if ~isempty(difference)
        middle = median(difference);
        spread = 1.4826 * median(abs(difference - middle));
        frameOffset(k) = mean(difference(abs(difference - middle) <= 3 * spread + 1e-6));
        viewSpread(k)  = spread;
    end

    % Add the frame in.
    parity = mod(k, 2) + 1;
    for g = 1:numGrooves
        p = piece{g};
        if isempty(p)
            continue
        end
        top    = p.top    - frameOffset(k);
        bottom = p.bottom - frameOffset(k);
        [known, there] = lookUp(reference, sumTop, sumBottom, weight, p);
        good = ~isnan(top) & ~isnan(bottom) & ~(known & abs((top + bottom) / 2 - there) > reject);
        bins = p.bins(good);
        w = single(p.taper(good));
        t = p.track;
        sumTop(t, bins)    = sumTop(t, bins)    + w .* single(top(good));
        sumBottom(t, bins) = sumBottom(t, bins) + w .* single(bottom(good));
        weight(t, bins)    = weight(t, bins)    + w;
        halfTop(parity, t, bins)    = squeeze(halfTop(parity, t, bins)).'    + w .* single(top(good));
        halfBottom(parity, t, bins) = squeeze(halfBottom(parity, t, bins)).' + w .* single(bottom(good));
        halfWeight(parity, t, bins) = squeeze(halfWeight(parity, t, bins)).' + w;
    end
end

seen = weight > 0.3;
mosaic.top    = sumTop ./ max(weight, 1e-6);
mosaic.bottom = sumBottom ./ max(weight, 1e-6);
mosaic.top(~seen)    = NaN;
mosaic.bottom(~seen) = NaN;
mosaic.weight     = weight;
mosaic.halfTop    = halfTop;
mosaic.halfBottom = halfBottom;
mosaic.halfWeight = halfWeight;
mosaic.firstId    = firstId;
mosaic.binOffset  = binOffset;
mosaic.frameOffset = frameOffset;
mosaic.framePosition = position;
mosaic.viewSpread  = viewSpread;
mosaic.shape = [tilt, bend];
end


function [known, there] = lookUp(reference, sumTop, sumBottom, weight, p)
% What is already known about the bins this piece covers: from the
% reference mosaic if there is one, else from the mosaic built so far.
if isempty(reference)
    w = weight(p.track, p.bins);
    known = w > 0.05;
    there = double(sumTop(p.track, p.bins) + sumBottom(p.track, p.bins)) ./ (2 * max(double(w), 1e-6));
else
    there = double(reference.top(p.track, p.bins) + reference.bottom(p.track, p.bins)) / 2;
    known = ~isnan(there);
end
end


function values = sampleAt(line, x)
% Linear interpolation of one edge at fractional columns x.
left = floor(x);
left = min(max(left, 1), numel(line) - 1);
fraction = x - left;
values = (1 - fraction) .* double(line(left)) + fraction .* double(line(left + 1));
end


function [tilt, bend] = commonShape(allEdges, half)
% Grooves are arcs, and tilted if the camera is not square to the radius.
% Every groove shows the same tilt and bend; the audio differs from groove
% to groove and drops out of the median.
width  = size(allEdges{1}.top, 2);
middle = round(width / 2);
columns = middle - floor(half) : middle + floor(half);
x = columns - (width + 1) / 2;
frames = round(linspace(1, numel(allEdges), min(numel(allEdges), 100)));
fits = zeros(numel(frames), 2);
for n = 1:numel(frames)
    e = allEdges{frames(n)};
    centre = (double(e.top(:, columns)) + double(e.bottom(:, columns))) / 2;
    centre = centre(~any(isnan(centre), 2), :);
    profile = median(centre - mean(centre, 2), 1);
    fit = polyfit(x, profile, 2);
    fits(n, :) = fit(1:2);
end
bend = median(fits(:, 1));
tilt = median(fits(:, 2));
end
