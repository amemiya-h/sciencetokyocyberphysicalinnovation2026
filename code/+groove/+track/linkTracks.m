function tracks = linkTracks(edges, cfg)
%LINKTRACKS  Follow each groove from one scan sample to the next.
%
%   tracks = groove.track.linkTracks(edges, cfg)
%
%   edges   output of groove.scan.extractEdges
%   tracks  struct with inner and outer (numTracks x numColumns, mm). Row k
%           is one groove band followed along the whole scan, NaN where it
%           was not detected. samplesPerRev is carried over.
%
%   A detection joins the nearest live track if it lies within
%   cfg.track.gateUm of where that track was last seen; otherwise it starts
%   a new track. A track unseen for cfg.track.maxGapSamples is retired.

gate   = cfg.track.gateUm * 1e-3;
maxGap = cfg.track.maxGapSamples;
numColumns = size(edges.inner, 2);

capacity = 2 * size(edges.inner, 1);
inner = nan(capacity, numColumns);
outer = nan(capacity, numColumns);
lastCentre = nan(capacity, 1);     % where each track was last seen
lastColumn = zeros(capacity, 1);   % and when
isLive     = false(capacity, 1);
numTracks  = 0;

for column = 1:numColumns
    found  = ~isnan(edges.inner(:, column));
    innerHere = edges.inner(found, column);
    outerHere = edges.outer(found, column);
    centreHere = (innerHere + outerHere) / 2;

    isLive(isLive & (column - lastColumn > maxGap)) = false;
    candidates = find(isLive);

    for k = 1:numel(centreHere)
        track = 0;
        if ~isempty(candidates)
            [distance, nearest] = min(abs(lastCentre(candidates) - centreHere(k)));
            if distance <= gate
                track = candidates(nearest);
                candidates(nearest) = [];   % one detection per track
            end
        end
        if track == 0
            numTracks = numTracks + 1;
            if numTracks > capacity
                inner = [inner; nan(capacity, numColumns)]; %#ok<AGROW>
                outer = [outer; nan(capacity, numColumns)]; %#ok<AGROW>
                lastCentre = [lastCentre; nan(capacity, 1)]; %#ok<AGROW>
                lastColumn = [lastColumn; zeros(capacity, 1)]; %#ok<AGROW>
                isLive = [isLive; false(capacity, 1)]; %#ok<AGROW>
                capacity = 2 * capacity;
            end
            track = numTracks;
            isLive(track) = true;
        end
        inner(track, column) = innerHere(k);
        outer(track, column) = outerHere(k);
        lastCentre(track) = centreHere(k);
        lastColumn(track) = column;
    end
end

tracks.inner = inner(1:numTracks, :);
tracks.outer = outer(1:numTracks, :);
tracks.samplesPerRev = edges.samplesPerRev;
end
