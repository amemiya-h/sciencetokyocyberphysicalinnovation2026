function [low, high] = detectGrooves(profile, threshold, limits)
%DETECTGROOVES  Find the grooves along one radial line of the image.
%
%   [low, high] = groove.scan.detectGrooves(profile, threshold, limits)
%
%   profile    brightness along one image column (land bright, walls dark)
%   threshold  brightness that separates land from groove
%   limits     struct in pixels: minWidth, maxWidth, maxGlint
%
%   low, high  row positions of the two edges of each groove, with
%              sub-pixel precision, low < high. Grooves touching the image
%              border are dropped because one of their edges is unseen.

profile = profile(:).';
isDark  = profile < threshold;

% Runs of dark pixels: run k covers rows first(k)..last(k).
change = diff([false, isDark, false]);
first  = find(change == 1);
last   = find(change == -1) - 1;

% A thin bright line inside a groove is the groove bottom, not land.
if numel(first) > 1
    gap     = first(2:end) - last(1:end-1) - 1;
    isGlint = gap <= limits.maxGlint;
    first([false, isGlint]) = [];
    last([isGlint, false])  = [];
end

seenWhole = first > 1 & last < numel(profile);
first = first(seenWhole);
last  = last(seenWhole);

% Sub-pixel edges: linear interpolation of the threshold crossing.
low  = (first - 1) + (profile(first - 1) - threshold) ./ (profile(first - 1) - profile(first));
high = last + (threshold - profile(last)) ./ (profile(last + 1) - profile(last));

width = high - low;
plausible = width >= limits.minWidth & width <= limits.maxWidth;
low  = low(plausible);
high = high(plausible);
end
