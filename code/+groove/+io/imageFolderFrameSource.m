function source = imageFolderFrameSource(folder, pattern)
%IMAGEFOLDERFRAMESOURCE  Frame source backed by numbered image files.
%
%   source = groove.io.imageFolderFrameSource('ring_01', '*.png')
%
%   Files are used in alphabetical order, so zero-pad the frame numbers
%   (frame_000001.png, frame_000002.png, ...).

listing = dir(fullfile(folder, pattern));
assert(~isempty(listing), 'No files matching %s in %s.', pattern, folder);
names = sort({listing.name});
paths = cellfun(@(n) fullfile(folder, n), names, 'UniformOutput', false);

first = groove.io.toGray(imread(paths{1}));
source.numFrames = numel(paths);
source.frameSize = size(first);
source.read      = @(i) groove.io.toGray(imread(paths{i}));
source.reopen    = @() groove.io.imageFolderFrameSource(folder, pattern);
end
