function chains = stitch_polar_chains(G, reg, cam, Rcam)
%STITCH_POLAR_CHAINS  Follow every groove through all unwarped images.
%   chains = STITCH_POLAR_CHAINS(G, reg, cam, Rcam) joins the lanes of
%   consecutive images (reg from register_polar) into chains; with a full
%   ring a chain that comes back to the first image continues one turn
%   further in. Along a chain, each image's lane is shifted radially to
%   agree with the one before it in their overlap (this takes out the
%   rig's wobble and anything else that moves a whole groove between
%   images), and overlapping images are cross-faded, so every view of a
%   point is averaged.
%
%   Output: struct array like stitch_groove_chains (longest first):
%     theta (rad), outer, inner, centre (radius, um), nodes [image, lane]

N = numel(G);
nP = size(reg.pairs, 1);
W = size(G{1}.c, 2);
H = cam.imageSize(1);
pixAng = cam.pixel / Rcam;
offCol = [0, cumsum(reg.shift(1:N-1))];          % image column 1 -> global column

succ = cell(1, N);  hasPred = cell(1, N);
for k = 1:N
    n = numel(G{k}.row0);
    succ{k} = zeros(n, 1);  hasPred{k} = false(n, 1);
end
for q = 1:nP
    a = reg.pairs(q, 1);  b = reg.pairs(q, 2);  m = reg.match{q};
    succ{a}(1:numel(m)) = m;
    hasPred{b}(m(m > 0)) = true;
end
visited = cell(1, N);
for k = 1:N, visited{k} = false(size(succ{k})); end

chains = struct('theta', {}, 'outer', {}, 'inner', {}, 'centre', {}, 'nodes', {});
for k0 = 1:N
    for i0 = find(~hasPred{k0})'
        nodes = [];  offs = [];
        k = k0;  i = i0;  off = offCol(k0);
        while i > 0 && ~visited{k}(i)
            visited{k}(i) = true;
            nodes(end+1, :) = [k, i];   %#ok<AGROW>
            offs(end+1) = off;          %#ok<AGROW>
            nxt = succ{k}(i);
            if k < N
                off = off + reg.shift(k);  k = k + 1;
            elseif nP == N
                off = off + reg.shift(N);  k = 1;
            else
                break;
            end
            i = nxt;
        end
        if size(nodes, 1) == 0, continue; end
        chains(end+1) = build(G, nodes, offs, W, H, cam, Rcam, pixAng); %#ok<AGROW>
    end
end
[~, order] = sort(arrayfun(@(c) numel(c.theta), chains), 'descend');
chains = chains(order);
end

function ch = build(G, nodes, offs, W, H, cam, Rcam, pixAng)
n = size(nodes, 1);
lo = floor(min(offs)) + 1;  hi = ceil(max(offs)) + W;
x = lo:hi;                                       % global columns
[sC, sW, wt] = deal(zeros(1, numel(x)));
prevC = nan(1, numel(x));
for s = 1:n
    g = G{nodes(s, 1)};  i = nodes(s, 2);
    xs = offs(s) + (1:W);                        % this image's columns, global
    k = (ceil(xs(1)) : floor(xs(end))) - lo + 1; % grid points inside the image
    xk = x(k);
    c = interp1(xs, double(g.c(i, :)), xk, 'linear', NaN);
    w = interp1(xs, double(g.w(i, :)), xk, 'linear', NaN);
    if s > 1
        d = c - prevC(k);
        d = d(~isnan(d));
        if numel(d) >= 16
            c = c - median(d);                   % agree with the previous image
        end
    end
    fw = max(min(xk - xs(1), xs(end) - xk), 0);  % cross-fade weight
    ok = ~isnan(c) & ~isnan(w) & fw > 0;
    kk = k(ok);
    sC(kk) = sC(kk) + fw(ok) .* c(ok);
    sW(kk) = sW(kk) + fw(ok) .* w(ok);
    wt(kk) = wt(kk) + fw(ok);
    prevC(:) = NaN;  prevC(k) = c;
end
cc = sC ./ wt;  ww = sW ./ wt;
keep = find(wt > 0, 1) : find(wt > 0, 1, 'last');
x = x(keep);  cc = cc(keep);  ww = ww(keep);
rowToR = @(row) Rcam - (row - (H + 1)/2) * cam.pixel;
ch.theta = (x - 1) * pixAng;
ch.outer = rowToR(cc - ww/2);
ch.inner = rowToR(cc + ww/2);
ch.centre = rowToR(cc);
ch.nodes = nodes;
end
