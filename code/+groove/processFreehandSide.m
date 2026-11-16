function [side, reports] = processFreehandSide(videoFiles, cfg)
%PROCESSFREEHANDSIDE  Several freehand rings -> one continuous groove.
%
%   [side, reports] = groove.processFreehandSide(videoFiles, cfg)
%
%   videoFiles  cell array of video files, one per radial position, each a
%               little more than one revolution, ordered from the outside
%               of the disc toward the label. Neighbouring rings must
%               overlap by at least two or three groove turns.
%   side        continuous groove at cfg.audio.sampleRate samples per second
%   reports     the groove.processFreehand report of every ring
%
%   Each ring is processed on its own, brought to the common sample rate,
%   and spliced to the previous one where their groove wiggles match.
%   With cfg.run.edgeCache set, each ring gets its own cache file
%   (<name>_ring01.mat, ...).

cfg.join.searchTurns = Inf;      % ring radii are only roughly known: search everywhere
[cacheFolder, cacheName] = fileparts(cfg.run.edgeCache);

side = [];
reports = cell(1, numel(videoFiles));
for k = 1:numel(videoFiles)
    fprintf('Ring %d of %d: %s\n', k, numel(videoFiles), videoFiles{k});
    ringCfg = cfg;
    if ~isempty(cfg.run.edgeCache)
        ringCfg.run.edgeCache = fullfile(cacheFolder, sprintf('%s_ring%02d.mat', cacheName, k));
    end
    source = groove.io.videoFrameSource(videoFiles{k});
    [ring, reports{k}] = groove.processFreehand(source, ringCfg);
    ring = groove.track.resampleRing(ring, cfg.audio.sampleRate, cfg);
    if isempty(side)
        side = ring;
    else
        side = groove.track.joinRings(side, ring, cfg);
    end
end
end
