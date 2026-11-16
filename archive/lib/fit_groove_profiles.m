function t = fit_groove_profiles(I, t, cam, opts)
%FIT_GROOVE_PROFILES  Groove centre and width by fitting an image model.
%   t = FIT_GROOVE_PROFILES(I, t, cam, opts) refines the tracks of one
%   image (from detect_grooves_frame) by fitting, column by column, a
%   model of what a groove looks like under coaxial light to all the
%   pixels across it, instead of taking the two steepest points:
%
%     m(y) = L - (L - D) * [Phi((y - c + w/2)/s) - Phi((y - c - w/2)/s)]
%            + g * exp(-(y - c)^2 / (2 tau^2))
%
%   a dark band of width w centred on c (rows), with walls blurred by s,
%   land brightness L, groove brightness D, and the thin bright line the
%   rounded groove bottom reflects (height g, width tau). Per column the
%   unknowns are c, w, L, D; s and g are shared by the whole groove in
%   the image. This is a regularised inverse problem:
%     - data: every pixel within half a groove spacing of the groove,
%       weighted by a robust (Huber) loss so dust and scratches, which
%       the model does not explain, pull little;
%     - prior: c and w change smoothly along the groove (penalty on their
%       second difference, set so it only removes detail shorter than
%       opts.cutoffPx pixels, i.e. above the audio band); L and D change
%       much more slowly.
%   Solved by Gauss-Newton with a sparse banded system per groove.
%
%   opts fields (defaults in brackets)
%     pitch     groove spacing (um) [120]
%     cutoffPx  shortest detail kept along the groove (px) [8]
%     iters     Gauss-Newton iterations [8]
%     huber     robust loss threshold, in noise sigmas [2]
%
%   Output: t with outer, inner = c -/+ w/2 replaced where fitted, and
%     t.c, t.w (rows, NaN where not fitted), t.sigma (wall blur, px per
%     groove), t.noise (pixel residual rms per groove), t.cStd (rough
%     standard error of c per column, px)

if nargin < 4, opts = struct(); end
def = struct('pitch', 120, 'cutoffPx', 8, 'iters', 8, 'huber', 2);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end
[H, W] = size(I);
h = round(0.55 * opts.pitch / cam.pixel);          % half window (rows)
nG = size(t.outer, 1);
t.c = nan(nG, W);  t.w = nan(nG, W);  t.cStd = nan(nG, W);
t.sigma = nan(nG, 1);  t.noise = nan(nG, 1);
kap = @(P) 1 / (2 - 2*cos(2*pi/P))^2;              % penalty for cutoff P

for i = 1:nG
    o = t.outer(i, :);  n = t.inner(i, :);
    ok = ~isnan(o) & ~isnan(n);
    if nnz(ok) < 20, continue; end
    J = find(ok, 1) : find(ok, 1, 'last');
    nJ = numel(J);
    c = interp1(find(ok), (o(ok) + n(ok)) / 2, J, 'linear');
    w = interp1(find(ok), n(ok) - o(ok), J, 'linear');
    % pixels around the starting centre; columns whose window leaves the
    % image get no data (the prior carries them)
    base = round(c) - h;
    rows = (0:2*h)' + base;                      % (2h+1) x nJ
    valid = rows >= 1 & rows <= H;
    colOK = all(valid, 1);
    if nnz(colOK) < 20, continue; end            % groove too close to the image edge
    rows = min(max(rows, 1), H);
    Y = I(sub2ind([H W], rows, repmat(J, 2*h+1, 1)));
    % starting brightness: land = bright quantile, groove = dark quantile
    L = prctile_cols(Y, 90);  D = prctile_cols(Y, 10);
    s = 1.5;  g = 0;  tau = max(1, 0.12 * median(w));
    rw = double(colOK);                          % column weights (0 = no data)
    for it = 1:opts.iters
        [M, dc, dw, dL, dD, ds, dg] = model(rows, c, w, L, D, s, g, tau);
        R = Y - M;
        Rok = R(:, colOK);
        sc = 1.4826 * median(abs(Rok(:)));
        wt = min(1, opts.huber * sc ./ max(abs(R), eps)) .* rw;
        % per-column 4x4 normal equations (block diagonal)
        G = {dc, dw, dL, dD};
        A = zeros(4, 4, nJ);  b = zeros(4, nJ);
        for p = 1:4
            b(p, :) = sum(wt .* G{p} .* R, 1);
            for q = p:4
                A(p, q, :) = reshape(sum(wt .* G{p} .* G{q}, 1), 1, 1, nJ);
                A(q, p, :) = A(p, q, :);
            end
        end
        % prior strengths from the typical information per column
        infoC = median(squeeze(A(1, 1, colOK)));  infoW = median(squeeze(A(2, 2, colOK)));
        infoL = median(squeeze(A(3, 3, colOK)));  infoD = median(squeeze(A(4, 4, colOK)));
        lam = [infoC * kap(opts.cutoffPx), infoW * kap(opts.cutoffPx), ...
               infoL * kap(200), infoD * kap(200)];
        % assemble the sparse system, unknowns ordered [c w L D] per column
        [ii, jj] = ndgrid(1:4, 1:4);
        Ir = (0:nJ-1) * 4 + ii(:);  Jr = (0:nJ-1) * 4 + jj(:);
        Ablk = sparse(Ir(:), Jr(:), reshape(A, [], 1), 4*nJ, 4*nJ);
        D2 = spdiags(ones(nJ, 1) * [1 -2 1], 0:2, nJ - 2, nJ);
        P = kron(D2' * D2, spdiags(lam(:), 0, 4, 4));
        x = [c; w; L; D];
        rhs = b(:) - P * x(:);
        mu = 1e-6 * mean(diag(Ablk));            % slight damping
        step = (Ablk + P + mu * speye(4*nJ)) \ rhs;
        step = reshape(step, 4, nJ);
        % keep steps sane (a fraction of a groove width per iteration)
        step(1:2, :) = max(min(step(1:2, :), 0.3 * h), -0.3 * h);
        c = c + step(1, :);  w = max(w + step(2, :), 2);
        L = L + step(3, :);  D = D + step(4, :);
        % shared blur and bottom line
        Gs = [ds(:), dg(:)] .* sqrt(wt(:));
        sg = (Gs' * Gs + 1e-9 * eye(2)) \ (Gs' * (sqrt(wt(:)) .* R(:)));
        s = min(max(s + sg(1), 0.3), 0.3 * h);
        g = max(g + sg(2), 0);
        if max(abs(step(1, colOK))) < 1e-3, break; end
    end
    % rough standard error of c: noise over the information in c
    cStd = sc ./ sqrt(max(squeeze(A(1, 1, :))', eps));
    c(~colOK) = NaN;  w(~colOK) = NaN;
    t.c(i, J) = c;  t.w(i, J) = w;  t.cStd(i, J) = cStd;
    t.sigma(i) = s;  t.noise(i) = sc;
    t.outer(i, J) = c - w/2;
    t.inner(i, J) = c + w/2;
end
end

function [M, dc, dw, dL, dD, ds, dg] = model(rows, c, w, L, D, s, g, tau)
a = (rows - c + w/2) / s;
b = (rows - c - w/2) / s;
Pa = 0.5 * erfc(-a / sqrt(2));  Pb = 0.5 * erfc(-b / sqrt(2));
pa = exp(-a.^2/2) / sqrt(2*pi);  pb = exp(-b.^2/2) / sqrt(2*pi);
band = Pa - Pb;
e = exp(-(rows - c).^2 / (2*tau^2));
K = L - D;
M = L - K .* band + g * e;
dc = K / s .* (pa - pb) + g * e .* (rows - c) / tau^2;
dw = -K / (2*s) .* (pa + pb);
dL = 1 - band;
dD = band;
ds = K / s .* (a .* pa - b .* pb);
dg = e;
end

function q = prctile_cols(Y, p)
Ys = sort(Y, 1);
q = Ys(max(1, round(p/100 * size(Y, 1))), :);
end
