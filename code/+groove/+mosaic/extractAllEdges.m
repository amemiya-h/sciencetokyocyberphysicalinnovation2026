function allEdges = extractAllEdges(source, cfg)
%EXTRACTALLEDGES  Groove edges of every frame of a scan.
%
%   allEdges = groove.mosaic.extractAllEdges(source, cfg)
%
%   allEdges  cell array, one groove.mosaic.frameEdges result per frame
%
%   This is the slow step, and every frame is independent of the others,
%   so with cfg.run.parallel the frames are shared out between the parallel
%   workers. Each worker opens the video for itself (source.reopen),
%   because a video reader cannot be handed from one process to another.

numFrames = source.numFrames;
canReopen = isfield(source, 'reopen');

if ~(cfg.run.parallel && canReopen)
    allEdges = cell(1, numFrames);
    for k = 1:numFrames
        allEdges{k} = groove.mosaic.frameEdges(source.read(k), cfg);
        if mod(k, 100) == 0
            fprintf('  edges: frame %d of %d\n', k, numFrames);
        end
    end
    return
end

% Consecutive frames stay together: reading a video in order is much
% faster than jumping around in it.
chunkSize = 25;
starts = 1:chunkSize:numFrames;
chunks = cell(1, numel(starts));
reopen = source.reopen;
parfor c = 1:numel(starts)
    reader = reopen();
    frames = starts(c):min(starts(c) + chunkSize - 1, numFrames);
    result = cell(1, numel(frames));
    for n = 1:numel(frames)
        result{n} = groove.mosaic.frameEdges(reader.read(frames(n)), cfg);
    end
    chunks{c} = result;
end
allEdges = [chunks{:}];
end
