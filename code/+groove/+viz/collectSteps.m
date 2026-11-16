function viz = collectSteps(source, cfg, frames, ring, report)
%COLLECTSTEPS  Gather one worked example of every step, for figures.
%
%   viz = groove.viz.collectSteps(source, cfg, frames, ring, report)
%
%   source        the scan's frame source
%   frames        a short run of consecutive frames to work on, e.g. 300:330
%   ring, report  the finished result of groove.processFreehand on the scan
%
%   Runs the real pipeline functions on the few frames and keeps the
%   intermediate values a figure needs. Nothing here is drawn; see
%   examples/visualize_steps.m. All lengths in viz are micrometres unless
%   the field name says otherwise.

pixelUm = cfg.camera.pixelSizeUm;
cfg.frameHeight = source.frameSize(1);
cfg.run.parallel = false;
subset = groove.io.subsetFrameSource(source, frames);

% --- Step 1: the image, and the edges found in it --------------------------
frame = subset.read(1);
allEdges = groove.mosaic.extractAllEdges(subset, cfg);
edges = allEdges{1};
[height, width] = size(frame);
zoomRows = round(height/2) + (-120:120);
zoomCols = round(width/2)  + (-160:160);
viz.frame = frame;
viz.zoomRows = zoomRows;
viz.zoomCols = zoomCols;
inZoom = edges.rows > zoomRows(1) + 10 & edges.rows < zoomRows(end) - 10;
viz.edgeTop    = double(edges.top(inZoom, zoomCols));
viz.edgeBottom = double(edges.bottom(inZoom, zoomCols));

% One column of brightness with the threshold crossings on it.
column = round(width / 2);
viz.profileRows = zoomRows;
viz.profile     = frame(zoomRows, column).';
viz.crossTop    = double(edges.top(inZoom, column)).';
viz.crossBottom = double(edges.bottom(inZoom, column)).';

% --- Step 2: from a curved, tilted line to the wiggle ----------------------
% The liveliest groove of the frame serves as the example from here on.
centre = (double(edges.top) + double(edges.bottom)) / 2;
x = (1:width) - (width + 1) / 2;
wiggle = nan(size(centre));
for g = 1:size(centre, 1)
    ok = ~isnan(centre(g, :));
    if mean(ok) > 0.98
        wiggle(g, ok) = centre(g, ok) - polyval(polyfit(x(ok), centre(g, ok), 2), x(ok));
    end
end
energy = mean(wiggle.^2, 2, 'omitnan');
energy(isnan(energy)) = -1;
[~, lively] = max(energy);
ok = ~isnan(centre(lively, :));
viz.grooveColumns = find(ok);
viz.grooveCentrePx = centre(lively, ok);
viz.grooveFitPx    = polyval(polyfit(x(ok), centre(lively, ok), 2), x(ok));
viz.grooveWiggle   = wiggle(lively, ok) * pixelUm;

% --- Step 3: how far did the disc move between two frames? -----------------
registration = groove.mosaic.registerFrames(allEdges, cfg);
id = registration.grooveId{1}(lively);
second = find(registration.grooveId{2} == id, 1);
centre2 = (double(allEdges{2}.top(second, :)) + double(allEdges{2}.bottom(second, :))) / 2;
ok2 = ~isnan(centre2);
wiggle2 = nan(1, width);
wiggle2(ok2) = centre2(ok2) - polyval(polyfit(x(ok2), centre2(ok2), 2), x(ok2));
viz.pairShiftPx = registration.position(2) - registration.position(1);
viz.pairWiggleA = wiggle(lively, :) * pixelUm;
viz.pairWiggleB = wiggle2 * pixelUm;
a = wiggle(lively, :);  a(isnan(a)) = 0;
b = wiggle2;            b(isnan(b)) = 0;
lags = -round(0.2 * width):round(0.6 * width);
match = zeros(size(lags));
for n = 1:numel(lags)
    L = lags(n);
    if L >= 0
        match(n) = sum(a(1:end - L) .* b(1 + L:end));
    else
        match(n) = sum(a(1 - L:end) .* b(1:end + L));
    end
end
viz.pairLags  = lags;
viz.pairMatch = match / sqrt(sum(a.^2) * sum(b.^2));
viz.framePositions = registration.position;

% --- Step 4: every view of the same stretch of groove, and their average ---
mosaic = groove.mosaic.buildMosaic(allEdges, registration, cfg);
track  = id - mosaic.firstId + 1;
half   = cfg.mosaic.halfWidthUm / pixelUm;
centreColumn = (width + 1) / 2;
views = {};
for k = 1:numel(allEdges)
    g = find(registration.grooveId{k} == id, 1);
    if isempty(g)
        continue
    end
    e = allEdges{k};
    columns = round(centreColumn - half):round(centreColumn + half);
    away = columns - centreColumn;
    line = (double(e.top(g, columns)) + double(e.bottom(g, columns))) / 2 ...
           - mosaic.shape(1) * away - mosaic.shape(2) * away.^2 - mosaic.frameOffset(k);
    view.bins = registration.position(k) - away / registration.scale(registration.rows{k}(g)) + mosaic.binOffset;
    view.rowPx = line;
    views{end + 1} = view; %#ok<AGROW>
end
mean_ = (mosaic.top(track, :) + mosaic.bottom(track, :)) / 2;
seenBins = find(mosaic.weight(track, :) > 1.5);              % where several views overlap
middle = seenBins(round(numel(seenBins) / 2));
window = middle + (-300:300);
reference = mean(mean_(window), 'omitnan');
viz.viewBins = window - window(1);
viz.viewMean = (double(mean_(window)) - reference) * pixelUm;
viz.viewLines = nan(numel(views), numel(window));
for n = 1:numel(views)
    viz.viewLines(n, :) = (interp1(views{n}.bins, views{n}.rowPx, window, 'linear', NaN) - reference) * pixelUm;
end
viz.viewLines = viz.viewLines(any(~isnan(viz.viewLines), 2), :);

% --- Step 5: closing the revolution ------------------------------------------
viz.closureLate  = ring.closureExample.lateUm;
viz.closureEarly = ring.closureExample.earlyUm;

% --- Step 6: from edges to sound ---------------------------------------------
fs = ring.sampleRate;
second = round(fs);
loudness = conv(abs(diff(ring.inner)), ones(1, second) / second, 'same');
[~, loudest] = max(loudness(second:end - 2*second));
excerpt = loudest + second + (0:2*second - 1);                 % two seconds around the loudest spot
piece = ring;
piece.inner = ring.inner(excerpt);
piece.outer = ring.outer(excerpt);
if isfield(piece, 'bridged')
    piece.bridged = ring.bridged(excerpt);
end
audioCfg = cfg;
audioCfg.audio.noiseProfile = report.noise;
audio = groove.audio.edgesToAudio(piece, audioCfg);
show = second + (1:round(0.03 * fs));                          % 30 ms in the middle
viz.musicTimeMs  = (0:numel(show) - 1) / fs * 1000;
viz.musicInner   = (piece.inner(show) - mean(piece.inner(show))) * 1e3;
viz.musicOuter   = (piece.outer(show) - mean(piece.outer(show))) * 1e3;
viz.musicLeft    = audio(show, 1).';
viz.musicRight   = audio(show, 2).';

% --- Step 7: how much of each frequency is groove, how much noise -----------
kernel = ones(1, 9) / 9;
total  = conv(report.noise.totalPower, kernel, 'same');
random = conv(report.noise.noisePower, kernel, 'same');
keep = report.noise.frequencyHz >= 30 & report.noise.frequencyHz <= 20000;
viz.spectrumHz    = report.noise.frequencyHz(keep);
viz.spectrumTotal = total(keep);
viz.spectrumNoise = random(keep);
viz.filterGain    = max(0, 1 - random(keep) ./ max(total(keep), eps));
viz.pixelUm = pixelUm;
end
