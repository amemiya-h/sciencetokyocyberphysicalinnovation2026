function subset = subsetFrameSource(source, frames)
%SUBSETFRAMESOURCE  A frame source showing only some frames of another.
%
%   subset = groove.io.subsetFrameSource(source, 200:350)
%
%   For trying settings or profiling on part of a scan.

subset.numFrames = numel(frames);
subset.frameSize = source.frameSize;
subset.read      = @(i) source.read(frames(i));
if isfield(source, 'reopen')
    reopen = source.reopen;
    subset.reopen = @() groove.io.subsetFrameSource(reopen(), frames);
end
end
