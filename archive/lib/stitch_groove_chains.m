function chains = stitch_groove_chains(tracks, reg, cam, Rcam)
%STITCH_GROOVE_CHAINS  Follow each groove through all frames.
%   chains = STITCH_GROOVE_CHAINS(tracks, reg, cam, Rcam) joins the groove
%   tracks of consecutive frames (reg.match from register_frames) into
%   chains. With a full ring (reg.pairs ends with [N 1]) a chain that
%   comes back to the first frame continues one turn further in, so it
%   follows the spiral for as many revolutions as there are grooves in
%   the field of view.
%
%   Each chain is sampled on a uniform grid of record angle; where frames
%   overlap, they are cross-faded (every view of a point is averaged).
%   If reg has an offset field (radial shift between frames, e.g. the
%   disc creeping over a ring), each frame's radii are shifted back by
%   the shifts accumulated along the chain so it stays continuous.
%
%   Output: struct array, one per chain, with fields
%     theta   1 x n record angle (rad), increasing in playing order,
%             0 = centre of the first frame
%     outer, inner, centre   1 x n radius (um) of the outer edge, inner
%             edge and their midpoint; NaN where not detected
%     nodes   [frame, track] list making up the chain

N = numel(tracks);
nP = size(reg.pairs, 1);
% Angular offset of every frame's centre (cumulative steps)
offset = [0, cumsum(reg.step(1:min(nP, N-1)))];
pixAng = cam.pixel / Rcam;
if isfield(reg, 'offset'), roffStep = reg.offset; else, roffStep = zeros(1, nP); end

% Successor of every node (frame k, track i) and whether it has a predecessor
succ = cell(1, N);
hasPred = cell(1, N);
for k = 1:N
    nk = size(tracks{k}.outer, 1);
    succ{k} = zeros(nk, 1);
    hasPred{k} = false(nk, 1);
end
for q = 1:nP
    a = reg.pairs(q, 1);  b = reg.pairs(q, 2);
    m = reg.match{q};
    succ{a}(1:numel(m)) = m;
    hasPred{b}(m(m > 0)) = true;
end

chains = struct('theta', {}, 'outer', {}, 'inner', {}, 'centre', {}, 'nodes', {});
visited = cell(1, N);
for k = 1:N, visited{k} = false(size(succ{k})); end

for k0 = 1:N
    for i0 = find(~hasPred{k0})'
        % Walk forward from a groove start
        nodes = [];  offs = [];  roffs = [];
        k = k0;  i = i0;  off = offset(k0);  roff = 0;
        while i > 0 && ~visited{k}(i)
            visited{k}(i) = true;
            nodes(end+1, :) = [k, i];   %#ok<AGROW>
            offs(end+1) = off;          %#ok<AGROW>
            roffs(end+1) = roff;        %#ok<AGROW>
            nxt = succ{k}(i);
            if k < N
                off = off + reg.step(k);
                roff = roff + roffStep(k);
                k = k + 1;
            elseif nP == N          % ring: last frame -> first, next revolution
                off = off + reg.step(N);
                roff = roff + roffStep(N);
                k = 1;
            else
                break;
            end
            i = nxt;
        end
        if size(nodes, 1) == 0, continue; end
        chains(end+1) = sample_chain(tracks, nodes, offs, roffs, cam, Rcam, reg.alpha, pixAng); %#ok<AGROW>
    end
end

% Longest first
[~, order] = sort(arrayfun(@(c) numel(c.theta), chains), 'descend');
chains = chains(order);
end

function c = sample_chain(tracks, nodes, offs, roffs, cam, Rcam, alpha, pixAng)
% Put the chain's edge samples on one uniform angle grid. Where images
% overlap, all of them are averaged, each weighted by how far the point
% is from that image's own ends (a cross-fade), so no step appears where
% one image hands over to the next, and points seen in several images
% get the benefit of all the views.
n = size(nodes, 1);
TO = cell(n, 1);  TI = TO;  RO = TO;  RI = TO;
for s = 1:n
    t = tracks{nodes(s, 1)};
    i = nodes(s, 2);
    W = size(t.outer, 2);
    [TO{s}, RO{s}] = frame_to_polar(t.outer(i, :), 1:W, cam, Rcam, alpha);
    [TI{s}, RI{s}] = frame_to_polar(t.inner(i, :), 1:W, cam, Rcam, alpha);
    TO{s} = TO{s} + offs(s);  TI{s} = TI{s} + offs(s);
    RO{s} = RO{s} - roffs(s);  RI{s} = RI{s} - roffs(s);
end
% Each groove's own offset between consecutive images (the image scale
% or rolling shutter can shift grooves at the top and bottom of an image
% differently, which one shift per image pair cannot remove): measured in
% the overlap; each image is aligned to the (already aligned) one before
for s = 2:n
    a = max(min(TO{s-1}), min(TO{s}));  b = min(max(TO{s-1}), max(TO{s}));
    if ~(b > a), continue; end
    g = linspace(a, b, 64);
    cPrev = (interp_nan(TO{s-1}, RO{s-1}, g) + interp_nan(TI{s-1}, RI{s-1}, g)) / 2;
    cHere = (interp_nan(TO{s}, RO{s}, g) + interp_nan(TI{s}, RI{s}, g)) / 2;
    d = cHere - cPrev;
    d = d(~isnan(d));
    if numel(d) < 8, continue; end
    RO{s} = RO{s} - median(d);  RI{s} = RI{s} - median(d);   % previous one is already aligned
end
lo = min(cellfun(@min, TO));  hi = max(cellfun(@max, TO));
grid = lo : pixAng : hi;
[sumO, sumI, wO, wI] = deal(zeros(size(grid)));
for s = 1:n
    a = min(TO{s});  b = max(TO{s});
    if isnan(a), continue; end
    k = max(1, ceil((a - lo) / pixAng) + 1) : min(numel(grid), floor((b - lo) / pixAng) + 1);
    if isempty(k), continue; end
    g = grid(k);
    fw = max(min(g - a, b - g), pixAng);           % cross-fade weight
    vo = interp_nan(TO{s}, RO{s}, g);  vi = interp_nan(TI{s}, RI{s}, g);
    ok = ~isnan(vo);  sumO(k(ok)) = sumO(k(ok)) + fw(ok) .* vo(ok);  wO(k(ok)) = wO(k(ok)) + fw(ok);
    ok = ~isnan(vi);  sumI(k(ok)) = sumI(k(ok)) + fw(ok) .* vi(ok);  wI(k(ok)) = wI(k(ok)) + fw(ok);
end
c.theta = grid;
c.outer = sumO ./ wO;  c.inner = sumI ./ wI;      % NaN where no view
c.centre = (c.outer + c.inner) / 2;
c.nodes = nodes;
end

function v = interp_nan(x, y, xq)
ok = ~isnan(y) & ~isnan(x);
v = nan(size(xq));
if nnz(ok) < 2, return; end
[x, k] = sort(x(ok));
y = y(ok);  y = y(k);
[x, u] = unique(x);
y = y(u);
v = interp1(x, y, xq, 'linear', NaN);
% leave gaps longer than 20 samples as NaN
gap = [false, diff(x) > 20 * median(diff(x))];
for g = find(gap)
    v(xq > x(g-1) & xq < x(g)) = NaN;
end
end
