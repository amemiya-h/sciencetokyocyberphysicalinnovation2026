function edges = frameEdges(frame, cfg)
%FRAMEEDGES  Both edges of every groove across the whole width of one frame.
%
%   edges = groove.mosaic.frameEdges(frame, cfg)
%
%   frame   grayscale image, grooves running horizontally, land bright
%   edges   struct
%     top, bottom  row position of each groove's upper and lower edge at
%                  every image column (numGrooves x width, single, NaN where
%                  not found), grooves ordered from the top of the image
%     rows         each groove's mean row near the image centre
%
%   The land/groove threshold follows the local bright and dark levels, so
%   vignetting and uneven lighting do not move the edges.

[height, width] = size(frame);
pixelUm = cfg.camera.pixelSizeUm;
minWidth = cfg.detect.minWidthUm / pixelUm;
maxWidth = cfg.detect.maxWidthUm / pixelUm;
window   = max(8, round(cfg.detect.localWindowUm / pixelUm));

% --- Threshold crossings in every column at once ---------------------------
[threshold, contrast] = localThreshold(frame, window);
level  = frame - threshold;
% Where there is no real light/dark contrast (blank land, the label, the
% disc rim) the threshold sits in the image noise and every flicker would
% look like a groove. Such regions count as land.
typical = median(contrast(:));
isDark  = level < 0 & contrast >= cfg.detect.minContrast * typical;
[fallRow, fallCol] = find(~isDark(1:end-1, :) &  isDark(2:end, :));
[riseRow, riseCol] = find( isDark(1:end-1, :) & ~isDark(2:end, :));
fallAt = subPixel(level, fallRow, fallCol, height);
riseAt = subPixel(level, riseRow, riseCol, height);

% A groove is a fall followed directly by a rise in the same column. Sort
% all crossings by (column, row) and keep the fall-rise neighbours.
position = [fallAt + height * (fallCol - 1); riseAt + height * (riseCol - 1)];
isRise   = [false(numel(fallAt), 1); true(numel(riseAt), 1)];
column   = [fallCol; riseCol];
[position, order] = sort(position);
isRise = isRise(order);
column = column(order);
first  = find(~isRise(1:end-1) & isRise(2:end) & column(1:end-1) == column(2:end));
top    = position(first)     - height * (column(first) - 1);
bottom = position(first + 1) - height * (column(first) - 1);
column = column(first);
plausible = (bottom - top) >= minWidth & (bottom - top) <= maxWidth;
top = top(plausible);  bottom = bottom(plausible);  column = column(plausible);

% --- Find the grooves near the centre, then follow each one sideways -------
count  = accumarray(column, 1, [width, 1]);
offset = [0; cumsum(count)];                 % detections of column c: offset(c)+1 .. offset(c+1)
centreColumn = round(width / 2);

% Which grooves exist is decided from a band of columns around the centre,
% not from one column: a speck on the sensor or the disc that hides a groove
% in a single column must not lose that groove for the whole frame.
seedColumns = max(1, centreColumn - 10) : min(width, centreColumn + 10);
inBand  = offset(seedColumns(1)) + 1 : offset(seedColumns(end) + 1);
centres = sort((top(inBand) + bottom(inBand)) / 2);
split   = 0.5 * median(bottom(inBand) - top(inBand));      % grooves are further apart than this
starts  = [1; find(diff(centres) > split) + 1];
stops   = [starts(2:end) - 1; numel(centres)];
enough  = (stops - starts + 1) >= numel(seedColumns) / 2;  % seen in most of the band
starts  = starts(enough);
stops   = stops(enough);
numGrooves = numel(starts);
seed = zeros(numGrooves, 1);
for g = 1:numGrooves
    seed(g) = median(centres(starts(g):stops(g)));
end

edges.top    = nan(numGrooves, width, 'single');
edges.bottom = nan(numGrooves, width, 'single');
gate = 0.2 * median(diff(seed));                            % a fifth of the pitch

% Follow each groove sideways from the centre, one column at a time.
for direction = [1, -1]
    last = seed;
    if direction == 1
        c = centreColumn;
    else
        c = centreColumn - 1;
    end
    while c >= 1 && c <= width
        here = offset(c) + (1:count(c)).';
        if numel(here) >= 2
            centre  = (top(here) + bottom(here)) / 2;
            [~, nearest] = min(abs(centre.' - last), [], 2);
            found   = abs(centre(nearest) - last) < gate;
            edges.top(found, c)    = top(here(nearest(found)));
            edges.bottom(found, c) = bottom(here(nearest(found)));
            last(found) = centre(nearest(found));
        end
        c = c + direction;
    end
end

edges.rows = groove.mosaic.centreRows(edges);
end


function [threshold, contrast] = localThreshold(frame, window)
% Midway between the local bright and dark levels, and their difference.
% The levels are the maximum and minimum over blocks of rows, joined
% smoothly between blocks.
height = size(frame, 1);
numBlocks = floor(height / window);
used   = frame(1:numBlocks * window, :);
blocks = reshape(used, window, numBlocks, []);
bright = squeeze(max(blocks, [], 1));          % numBlocks x width
dark   = squeeze(min(blocks, [], 1));
threshold = betweenBlocks((bright + dark) / 2, window, height);
contrast  = betweenBlocks(bright - dark, window, height);
end


function full = betweenBlocks(perBlock, window, height)
% One value per block of rows -> one value per row, linear in between and
% held constant beyond the first and last block centre.
numBlocks = size(perBlock, 1);
blockCentre = ((1:numBlocks) - 0.5) * window + 0.5;
full = interp1(blockCentre(:), perBlock, (1:height).', 'linear', 'extrap');
head = 1:floor(blockCentre(1));
tail = ceil(blockCentre(end)):height;
full(head, :) = repmat(perBlock(1, :),   numel(head), 1);
full(tail, :) = repmat(perBlock(end, :), numel(tail), 1);
end


function at = subPixel(level, row, col, height)
% Where the level crosses zero between row and row+1, by linear interpolation.
index = row + height * (col - 1);
at = row + level(index) ./ (level(index) - level(index + 1));
end
