function kymograph = buildKymograph(source, cfg, columns)
%BUILDKYMOGRAPH  The unwound groove picture, for checking a setup by eye.
%
%   kymograph = groove.scan.buildKymograph(source, cfg, columns)
%
%   columns    scan samples to render, e.g. 1:20:40000 (default: every 50th)
%   kymograph  image with radius down the rows and disc angle along the
%              columns. With a good setup every groove is a clean dark band
%              with sharp edges, drifting slowly as the spiral advances.
%              View it with imagesc(kymograph); colormap gray
%
%   The pipeline itself never builds this image; it is a diagnostic.

geo = groove.scan.geometry(cfg, source);
if nargin < 3
    columns = 1:50:geo.numColumns;
end

kymograph = zeros(source.frameSize(1), numel(columns));
loadedFrame = 0;
for k = 1:numel(columns)
    column = columns(k);
    if geo.frameOf(column) ~= loadedFrame
        loadedFrame = geo.frameOf(column);
        frame = source.read(loadedFrame);
    end
    kymograph(:, k) = groove.scan.sliceProfile(frame, geo.leftEdge(column), geo.rightEdge(column));
end
end
