function tr = track_groove_dataset(dataDir, meta, trackOpts)
%TRACK_GROOVE_DATASET  Track groove edges through every frame of a dataset.
%   tr = TRACK_GROOVE_DATASET(dataDir, meta, trackOpts) reads the frames
%   written by write_groove_dataset one at a time, runs
%   track_groove_edges on each, and carries the centre estimate across
%   frame boundaries.
%
%   Inputs
%     dataDir    dataset folder
%     meta       struct loaded from dataDir/meta.mat
%     trackOpts  as for track_groove_edges (startCentre is the start of
%                the first frame)
%
%   Output
%     tr   as from track_groove_edges, covering all rows of the groove

nRows = numel(meta.y);
tr.left = nan(nRows, 1);
tr.right = nan(nRows, 1);
tr.centre = nan(nRows, 1);

for k = 1:meta.nFrames
    [I, rows] = read_groove_frame(dataDir, meta, k);
    blk = track_groove_edges(I, meta.x, trackOpts);

    tr.left(rows) = blk.left;
    tr.right(rows) = blk.right;
    tr.centre(rows) = blk.centre;

    lastValid = find(~isnan(blk.centre), 1, 'last');
    if ~isempty(lastValid)
        trackOpts.startCentre = blk.centre(lastValid);
    end

    if mod(k, 10) == 0 || k == meta.nFrames
        fprintf('  tracked frame %d / %d\n', k, meta.nFrames);
    end
end
end
