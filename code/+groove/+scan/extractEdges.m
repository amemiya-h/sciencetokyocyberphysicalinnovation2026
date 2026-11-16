function edges = extractEdges(source, cfg)
%EXTRACTEDGES  Measure both edges of every groove at every scan sample.
%
%   edges = groove.scan.extractEdges(source, cfg)
%
%   edges.inner  radius (mm) of the spindle-side edge of each groove
%   edges.outer  radius (mm) of the rim-side edge of each groove
%                Both are maxGrooves x numColumns, padded with NaN. Within a
%                column the grooves are in no guaranteed order; linking them
%                along the scan is the job of groove.track.linkTracks.
%   edges.samplesPerRev  scan samples per revolution
%
%   Columns run in playback order regardless of how the disc was turned.

geo = groove.scan.geometry(cfg, source);

limits.minWidth = cfg.detect.minWidthUm / cfg.camera.pixelSizeUm;
limits.maxWidth = cfg.detect.maxWidthUm / cfg.camera.pixelSizeUm;
limits.maxGlint = cfg.detect.maxGlintUm / cfg.camera.pixelSizeUm;

inner = nan(cfg.detect.maxGrooves, geo.numColumns);
outer = nan(cfg.detect.maxGrooves, geo.numColumns);

for frameIndex = 1:source.numFrames
    columns = find(geo.frameOf == frameIndex);
    if isempty(columns)
        continue
    end
    frame = source.read(frameIndex);
    strip = frame(:, ceil(min(geo.leftEdge(columns))):floor(max(geo.rightEdge(columns))));
    threshold = edgeThreshold(strip, cfg.detect.threshold);

    for column = columns
        profile = groove.scan.sliceProfile(frame, geo.leftEdge(column), geo.rightEdge(column));
        [low, high] = groove.scan.detectGrooves(profile, threshold, limits);

        radiusA = rowToRadius(low,  cfg, geo) + geo.sagittaMm(column);
        radiusB = rowToRadius(high, cfg, geo) + geo.sagittaMm(column);
        count = min(numel(low), cfg.detect.maxGrooves);
        inner(1:count, column) = min(radiusA(1:count), radiusB(1:count));
        outer(1:count, column) = max(radiusA(1:count), radiusB(1:count));
    end
end

if ~cfg.turntable.playbackDirection
    inner = fliplr(inner);
    outer = fliplr(outer);
end

edges.inner = inner;
edges.outer = outer;
edges.samplesPerRev = geo.samplesPerRev;
end


function threshold = edgeThreshold(strip, fraction)
% Level between the typical wall brightness and the typical land brightness.
values = sort(strip(:));
dark   = values(max(1, round(0.05 * numel(values))));
bright = values(round(0.95 * numel(values)));
threshold = dark + fraction * (bright - dark);
end


function radius = rowToRadius(row, cfg, geo)
radius = cfg.ring.radiusMm + geo.rowSign * (row - geo.centreRow) * geo.pixelMm;
end
