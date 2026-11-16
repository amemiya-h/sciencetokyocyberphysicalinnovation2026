function source = videoFrameSource(filename)
%VIDEOFRAMESOURCE  Frame source backed by a video file.
%
%   source = groove.io.videoFrameSource('ring_01.avi')
%
%   A frame source is a struct with
%     numFrames   number of frames
%     frameSize   [rows cols]
%     read(i)     function returning frame i as a double image in [0, 1]
%     reopen()    function returning a fresh copy of the source; parallel
%                 workers each need their own video reader
%
%   Use a lossless or lightly compressed format: compression artefacts
%   move the groove edges. Needs MATLAB R2020b or newer (VideoReader.NumFrames).

video = VideoReader(filename);
source.numFrames = video.NumFrames;
source.frameSize = [video.Height, video.Width];
source.read      = @(i) groove.io.toGray(read(video, i));
source.reopen    = @() groove.io.videoFrameSource(filename);
end
