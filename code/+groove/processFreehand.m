function [ring, report] = processFreehand(source, cfg)
%PROCESSFREEHAND  Video of a disc turned by hand -> unwound groove edges.
%
%   [ring, report] = groove.processFreehand(source, cfg)
%
%   For scans where nothing tells which disc angle a frame shows: the disc
%   was turned by hand, or by a motor that is not synchronised with the
%   camera. Frames are placed by matching the groove wiggles they share,
%   all views of each groove are averaged, and the revolution is found
%   from the music repeating one groove over.
%
%   Requirements: grooves horizontal in the image, consecutive frames
%   overlapping by at least half a frame, a little more than one
%   revolution filmed at one radial position.
%
%   Reading the edges is the slow step. Set cfg.run.edgeCache to a .mat
%   file name to keep them: a rerun then starts at registration. The cache
%   is ignored and rewritten when the detection settings, pixel size or
%   video have changed.
%
%   report.timing lists the seconds spent in each stage.
%
%   Continue with groove.audio.edgesToAudio(ring, cfg) and
%   groove.track.groovePosition(ring, cfg), as for groove.processRing.

cfg.frameHeight = source.frameSize(1);
cache = cfg.run.edgeCache;

% The cache is only valid for the settings and video it was made with.
key.detect = cfg.detect;
key.pixelSizeUm = cfg.camera.pixelSizeUm;
key.numFrames = source.numFrames;
key.frameSize = source.frameSize;

stage = tic;
allEdges = {};
if ~isempty(cache) && exist(cache, 'file') == 2
    loaded = load(cache);
    if isfield(loaded, 'key') && isequal(loaded.key, key)
        fprintf('Loading groove edges from %s\n', cache);
        allEdges = loaded.allEdges;
    else
        fprintf('%s was made with other settings; reading the edges again\n', cache);
    end
    clear loaded
end
if isempty(allEdges)
    fprintf('Reading groove edges from %d frames\n', source.numFrames);
    allEdges = groove.mosaic.extractAllEdges(source, cfg);
    if ~isempty(cache)
        save(cache, 'allEdges', 'key', '-v7.3');
    end
end
edgeSeconds = toc(stage);

[ring, report] = groove.mosaic.fromEdges(allEdges, cfg);
report.timing.edgeSeconds = edgeSeconds;

fprintf('Recovered %d groove turns, %.1f s of audio\n', ring.numTurns, numel(ring.inner) / ring.sampleRate);
t = report.timing;
fprintf('Time: edges %.0f s, registration %.0f s, mosaic %.0f s, unwinding and noise %.0f s\n', ...
    t.edgeSeconds, t.registerSeconds, t.mosaicSeconds, t.unwindSeconds);
end
