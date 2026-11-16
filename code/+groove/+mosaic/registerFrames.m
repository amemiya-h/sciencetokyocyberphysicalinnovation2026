function registration = registerFrames(allEdges, cfg)
%REGISTERFRAMES  Place every frame along the groove, from the grooves alone.
%
%   registration = groove.mosaic.registerFrames(allEdges, cfg)
%
%   Needed when the disc angle of each frame is unknown (hand turning, a
%   slipping belt). With a stepper and a triggered camera the positions
%   are known and this step could be replaced by arithmetic.
%
%   registration fields
%     position   where each frame sits along the groove at the centre row,
%                in pixels, starting at 0                 (1 x numFrames)
%     scaleCoefficients   how the shift grows with distance from the
%                centre row: scale = 1 + c1*d + c2*d^2
%     scale      the same as a function of row
%     grooveId   for each frame, a number per groove that follows the same
%                physical groove band from frame to frame; it rises by one
%                per groove toward the bottom of the image
%     rows       each frame's groove rows
%     score      match quality of each consecutive pair, 0..1
%     radial     sideways slip between consecutive frames, pixels

numFrames = numel(allEdges);
height    = cfg.frameHeight;
centreRow = (height + 1) / 2;

% Two passes: the first assumes every row moves alike, which is enough to
% measure how the movement really scales with row; the second uses that.
coefficients = [0, 0];
for pass = 1:2
    scale = @(row) 1 + coefficients(1) * (row - centreRow) + coefficients(2) * (row - centreRow).^2;
    shifts = cell(1, numFrames - 1);
    previous = groove.mosaic.prepareFrame(allEdges{1});
    for k = 1:numFrames - 1
        current   = groove.mosaic.prepareFrame(allEdges{k + 1});
        shifts{k} = groove.mosaic.pairShift(previous, current, scale, cfg);
        previous  = current;
    end
    [centreShift, coefficients] = fitShifts(shifts, allEdges, centreRow);
    fprintf('  registration pass %d: shift scales by %.2f%% across the frame height\n', ...
        pass, -100 * coefficients(1) * height);
end

registration.position = [0, cumsum(centreShift)];
registration.scaleCoefficients = coefficients;
registration.scale    = @(row) 1 + coefficients(1) * (row - centreRow) + coefficients(2) * (row - centreRow).^2;
registration.score    = cellfun(@(s) s.score,  shifts);
registration.radial   = cellfun(@(s) s.radial, shifts);
[registration.grooveId, registration.rows] = labelGrooves(shifts, allEdges);
end


function [centreShift, coefficients] = fitShifts(shifts, allEdges, centreRow)
% Per pair: a robust straight line through the grooves' own shifts against
% row gives the shift at the centre row. Pooled over all pairs: the
% relative change with row, which is a property of the rig.
numPairs = numel(shifts);
centreShift = zeros(1, numPairs);
pooledRow = cell(1, numPairs);
pooledRelative = cell(1, numPairs);
for k = 1:numPairs
    s = shifts{k};
    centreShift(k) = s.centre;
    clear_ = ~isnan(s.lag) & s.weight > 0.6;
    if sum(clear_) < 20
        continue
    end
    distance = allEdges{k}.rows(s.grooveA(clear_)) - centreRow;
    lag = s.lag(clear_);
    line = polyfit(distance, lag, 1);
    residual = lag - polyval(line, distance);
    inlier = abs(residual) < 3 * 1.4826 * median(abs(residual)) + 1e-3;
    line = polyfit(distance(inlier), lag(inlier), 1);
    centreShift(k) = line(2);
    if abs(line(2)) > 80          % only clear movements say anything about scale
        pooledRow{k} = distance(inlier);
        pooledRelative{k} = lag(inlier) / line(2) - 1;
    end
end
pooledRow = vertcat(pooledRow{:});
pooledRelative = vertcat(pooledRelative{:});
if numel(pooledRow) < 200
    coefficients = [0, 0];
    return
end
fit = polyfit(pooledRow, pooledRelative, 2);
coefficients = [fit(2), fit(1)];
end


function [grooveId, rows] = labelGrooves(shifts, allEdges)
% Carry groove numbers from frame to frame through the matches. A groove
% that has no match (it entered the view, or was missed in the previous
% frame) is numbered from its numbered neighbours.
numFrames = numel(allEdges);
grooveId = cell(1, numFrames);
rows     = cell(1, numFrames);
rows{1}  = allEdges{1}.rows(:);
grooveId{1} = (1:numel(rows{1})).';
for k = 2:numFrames
    rows{k} = allEdges{k}.rows(:);
    id = nan(numel(rows{k}), 1);
    id(shifts{k - 1}.grooveB) = grooveId{k - 1}(shifts{k - 1}.grooveA);
    grooveId{k} = numberUnmatched(id, rows{k});
end
end


function id = numberUnmatched(id, rows)
% Numbers rise by one per groove down the image. The groove spacing varies
% (loud passages are cut further apart), so an unnumbered groove between
% two numbered ones is placed by the spacing those two imply, not by a
% typical spacing; rounding against a typical spacing can land it on a
% number its neighbour already has.
known = find(~isnan(id));
typicalPitch = median(diff(rows));
for g = find(isnan(id)).'
    above = known(find(known < g, 1, 'last'));
    below = known(find(known > g, 1, 'first'));
    if ~isempty(above) && ~isempty(below)
        localPitch = (rows(below) - rows(above)) / (id(below) - id(above));
        steps = round((rows(g) - rows(above)) / localPitch);
        steps = min(max(steps, 1), id(below) - id(above) - 1);     % strictly between the two
        id(g) = id(above) + steps;
    elseif ~isempty(above)
        id(g) = id(above) + max(1, round((rows(g) - rows(above)) / typicalPitch));
    else
        id(g) = id(below) - max(1, round((rows(below) - rows(g)) / typicalPitch));
    end
    known = sort([known; g]);      % later grooves may lean on this one
end
end
