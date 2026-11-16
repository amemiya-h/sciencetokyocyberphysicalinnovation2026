function tracks = detect_grooves_frame(I, cam, opts)
%DETECT_GROOVES_FRAME  Find every groove's two edges in one image.
%   tracks = DETECT_GROOVES_FRAME(I, cam, opts) works on an image with the
%   grooves running roughly left-right, dark on bright land (coaxial
%   light), with the record's outer edge at the top. In every column it
%   finds the land->groove step (outer edge) and the groove->land step
%   (inner edge) to sub-pixel accuracy, keeps pairs whose spacing matches
%   a groove width, and links them from column to column into tracks.
%
%   Inputs
%     I     H x W image scaled to [0, 1]
%     cam   needs cam.pixel (um)
%     opts  struct with fields (defaults in brackets)
%       expectedWidth  groove width at the surface (um)
%       widthTol       accepted widths: expectedWidth*(1 -/+ widthTol) [0.35]
%       smooth         Gaussian smoothing across the groove, sigma (px) [1]
%       maxJump        largest move of a groove centre between columns (um) [12]
%       maxGap         columns a track may go undetected and continue [20]
%       minLength      shortest track kept, fraction of the width [0.15]
%
%   Output struct tracks
%     outer, inner   nTracks x W edge rows (1-based, sub-pixel; NaN where
%                    not detected). outer = upper edge in the image.

def = struct('widthTol', 0.35, 'smooth', 1, 'maxJump', 12, 'maxGap', 20, ...
             'minLength', 0.15);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end

[H, W] = size(I);
p = cam.pixel;
wLo = opts.expectedWidth * (1 - opts.widthTol) / p;
wHi = opts.expectedWidth * (1 + opts.widthTol) / p;

% Smooth across the grooves, then the gradient down each column
h = ceil(3 * opts.smooth);
g = exp(-0.5 * ((-h:h)' / opts.smooth).^2);
Is = conv2(g / sum(g), 1, I, 'same');
G = zeros(H, W);
G(2:H-1, :) = (Is(3:H, :) - Is(1:H-2, :)) / 2;

maxTracks = 4 * ceil(H * p / (opts.expectedWidth * 1.2)) + 50;
OUT = nan(maxTracks, W);
INN = nan(maxTracks, W);
lastC = nan(maxTracks, 1);        % last centre row of each track
lastJ = -inf(maxTracks, 1);       % last column it was seen
nT = 0;

for j = 1:W
    gcol = G(:, j);
    thr = 0.3 * max(abs(gcol));
    [fRows] = peaks_subpixel(-gcol, thr);      % falling: land -> groove
    [rRows] = peaks_subpixel(gcol, thr);       % rising:  groove -> land

    % Pair each falling edge with the next rising edge at a groove width
    tops = [];  bots = [];
    for a = 1:numel(fRows)
        d = rRows - fRows(a);
        k = find(d > wLo & d < wHi, 1);
        if ~isempty(k) && (a == numel(fRows) || fRows(a+1) > rRows(k))
            tops(end+1) = fRows(a);  bots(end+1) = rRows(k);   %#ok<AGROW>
        end
    end
    cen = (tops + bots) / 2;

    % Assign to tracks seen recently (nearest centre, greedy)
    active = find(j - lastJ(1:nT) <= opts.maxGap);
    used = false(size(cen));
    if ~isempty(active) && ~isempty(cen)
        D = abs(lastC(active) - cen);
        lim = (opts.maxJump / p) * max(1, j - lastJ(active));
        D(D > lim) = inf;
        while true
            [m, idx] = min(D(:));
            if isinf(m), break; end
            [ia, ic] = ind2sub(size(D), idx);
            t = active(ia);
            OUT(t, j) = tops(ic);  INN(t, j) = bots(ic);
            lastC(t) = cen(ic);  lastJ(t) = j;  used(ic) = true;
            D(ia, :) = inf;  D(:, ic) = inf;
        end
    end
    for ic = find(~used)
        if nT == maxTracks, break; end
        nT = nT + 1;
        OUT(nT, j) = tops(ic);  INN(nT, j) = bots(ic);
        lastC(nT) = cen(ic);  lastJ(nT) = j;
    end
end

% A blip on one edge (dust) can still split a groove in two: join pieces
% that follow on within maxGap columns at nearly the same centre
[OUT, INN, nT] = join_pieces(OUT, INN, nT, opts.maxGap, 0.4 * opts.expectedWidth / p);

keep = sum(~isnan(OUT(1:nT, :)), 2) >= opts.minLength * W;
tracks.outer = OUT(find(keep), :);   %#ok<FNDSB>
tracks.inner = INN(find(keep), :);   %#ok<FNDSB>
% Order from the top of the image (outer) down
[~, order] = sort(median_omitnan(tracks.outer, 2));
tracks.outer = tracks.outer(order, :);
tracks.inner = tracks.inner(order, :);
end

function [OUT, INN, nT] = join_pieces(OUT, INN, nT, maxGap, tol)
alive = true(nT, 1);
changed = true;
while changed
    changed = false;
    first = nan(nT, 1);  last = nan(nT, 1);
    for t = find(alive)'
        c = find(~isnan(OUT(t, :)));
        if isempty(c), alive(t) = false; continue; end
        first(t) = c(1);  last(t) = c(end);
    end
    for a = find(alive)'
        if ~alive(a), continue; end
        b = find(alive & first > last(a) & first <= last(a) + maxGap + 1);
        if isempty(b), continue; end
        ca = (OUT(a, last(a)) + INN(a, last(a))) / 2;
        cb = (OUT(sub2ind(size(OUT), b, first(b))) + INN(sub2ind(size(INN), b, first(b)))) / 2;
        [d, i] = min(abs(cb - ca));
        if d > tol, continue; end
        b = b(i);
        cols = first(b):last(b);
        OUT(a, cols) = OUT(b, cols);  INN(a, cols) = INN(b, cols);
        OUT(b, :) = NaN;  INN(b, :) = NaN;  alive(b) = false;
        last(a) = last(b);  first(b) = NaN;  last(b) = NaN;
        changed = true;
    end
end
end

function rows = peaks_subpixel(v, thr)
% Local maxima of v above thr, refined with a parabola
n = numel(v);
i = find(v(2:n-1) > thr & v(2:n-1) >= v(1:n-2) & v(2:n-1) > v(3:n)) + 1;
a = v(i-1);  b = v(i);  c = v(i+1);
den = a - 2*b + c;
s = zeros(size(i));
ok = den < 0;
s(ok) = min(max(0.5 * (a(ok) - c(ok)) ./ den(ok), -0.5), 0.5);
rows = (i + s)';
end
