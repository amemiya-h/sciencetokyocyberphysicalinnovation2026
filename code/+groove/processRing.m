function ring = processRing(source, cfg)
%PROCESSRING  Turn one revolution of video into unwound groove edges.
%
%   ring = groove.processRing(source, cfg)
%
%   source  frame source (see groove.io.videoFrameSource) holding a little
%           more than one revolution, filmed at a fixed radius
%   cfg     configuration; cfg.ring.radiusMm must be the radius at which
%           this video was filmed
%
%   ring    struct describing every complete groove turn seen in the video,
%           laid end to end in playback order (see groove.track.unwindRing)

edges  = groove.scan.extractEdges(source, cfg);
tracks = groove.track.linkTracks(edges, cfg);
ring   = groove.track.unwindRing(tracks, cfg);
end
