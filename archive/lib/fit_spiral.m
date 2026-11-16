function [sp, chain] = fit_spiral(G, reg, cam, Rcam, opts)
%FIT_SPIRAL  The groove as one spiral: music time -> position in every image.
%   [sp, chain] = FIT_SPIRAL(G, reg, cam, Rcam, opts) models the record as
%   one physical mapping instead of following grooves image by image:
%
%     music time  t = u T          (u = turns since the first one seen)
%     disc angle  theta = 2 pi u
%     radius      r(u) = r_silent(u) + x(u)
%
%   r_silent is the blank spiral: one groove spacing further in per turn,
%   the spacing changing slowly (variable pitch, a smooth curve with one
%   knot per turn), plus the once-per-turn swing of a disc that sits off
%   the rig axis (e cos(theta - theta_e)). x(u) is the cut, i.e. the
%   music. Each image k sees angles phi_k + its columns and radii
%   rho_k + its rows (its pose, from register_polar), so every groove
%   reading in every image is an observation of x at a known u:
%
%     1. put all readings on the disc (angle, radius) using the poses;
%     2. give each reading its turn number by unwrapping against the
%        spiral, fit r_silent, and repeat (turns are ~120 um apart, so the
%        assignment is unambiguous once the spiral is known);
%     3. remove each image's own small offset per groove (found where
%        images overlap: the same u seen twice must agree);
%     4. average all views of each u onto one uniform grid, correcting the
%        angle for the off-centre disc (otherwise heard as wow).
%
%   Inputs: G (read_grooves_polar per image), reg (register_polar, ring
%   shifts already scaled to one revolution), opts.ring [true]
%
%   Outputs
%     sp     struct: u (grid, turns), x (um), w (width, um), rs (silent
%            spiral, um), nViews (views per sample), pitch (um/turn),
%            ecc (A, B, e in um)
%     chain  the same as a single chain for chain_to_audio:
%            theta, outer, inner, centre (um), nodes ([])

if nargin < 5, opts = struct(); end
if ~isfield(opts, 'ring'), opts.ring = true; end
N = numel(G);
[nLane, W] = deal(cellfun(@(g) numel(g.row0), G), size(G{1}.c, 2));
H = cam.imageSize(1);
p = cam.pixel;
revCols = 2*pi * Rcam / p;                         % columns per revolution

% 1. Image poses: angle (columns) and radial shift (rows) of each image
phi = [0, cumsum(reg.shift(1:N-1))];
drow = reg.drow(1:N-1);  drow(isnan(drow)) = 0;
rho = [0, cumsum(drow)];
if opts.ring && numel(reg.shift) == N && ~isnan(reg.drow(N))
    eps_ = rho(N) + reg.drow(N);                   % should come back to 0
    rho = rho - eps_ * (0:N-1) / N;                % spread the leftover over time
end

% all readings: u0 (turn fraction from the image's angle), r (um), w, weight
nObs = sum(nLane) * W;
[U0, R, Wd, Wt, IMG, LN] = deal(zeros(nObs, 1));
o = 0;
cols = 1:W;
fw = min(cols - 1, W - cols) + 1;                  % cross-fade weight
for k = 1:N
    g = G{k};
    for i = 1:numel(g.row0)
        c = double(g.c(i, :));  w = double(g.w(i, :));
        ok = ~isnan(c) & ~isnan(w);
        n = nnz(ok);
        if n == 0, continue; end
        idx = o + (1:n);
        U0(idx) = (phi(k) + cols(ok)) / revCols;
        R(idx) = Rcam - (c(ok) - rho(k) - (H + 1)/2) * p;   % back into image 1's rows
        Wd(idx) = w(ok) * p;
        Wt(idx) = fw(ok);
        IMG(idx) = k;  LN(idx) = i;
        o = o + n;
    end
end
U0 = U0(1:o);  R = R(1:o);  Wd = Wd(1:o);  Wt = Wt(1:o);  IMG = IMG(1:o);  LN = LN(1:o);
U0 = mod(U0, 1);                                   % angle as a fraction of a turn

% 2. Turn numbers and the silent spiral
% first guess: radius falls by one pitch per turn
pitch0 = median(cellfun(@(g) median(diff(g.row0)), G)) * p;
R0 = max(R);
n = round((R0 - R) / pitch0 - U0);
for it = 1:4
    u = n + U0;
    [rs, coef] = silent_spiral(u, R, Wt);
    % re-assign each reading to the turn whose silent radius is nearest
    best = n;  bestD = abs(R - rs);
    for dn = [-1, 1]
        rs2 = eval_spiral(n + dn + U0, coef);
        d = abs(R - rs2);
        better = d < bestD;
        best(better) = n(better) + dn;  bestD(better) = d(better);
    end
    if isequal(best, n), break; end
    n = best;
end
u = n + U0;
[rs, coef] = silent_spiral(u, R, Wt);
x = R - rs;
pitch = -coef.slope;                               % um per turn (median)

% 3. Each image's own offset per groove, from the overlaps
grp = (IMG - 1) * max(nLane) + LN;
ug = round((u - min(u)) * revCols) + 1;            % grid sample of each reading
off = zeros(max(grp), 1);
for it = 1:3
    xa = x - off(grp);
    m = accumarray(ug, Wt .* xa) ./ max(accumarray(ug, Wt), eps);
    res = xa - m(ug);
    off = off + accumarray(grp, res, [max(grp), 1], @median);
end
x = x - off(grp);

% 4. Off-centre disc: angle about the spiral centre, then the uniform grid
th = 2*pi * u;
uC = u - (coef.B * cos(th) - coef.A * sin(th)) ./ R / (2*pi);
uMin = min(uC);
gi = (uC - uMin) * revCols;                        % fractional grid index (0-based)
i0 = floor(gi);  f1 = gi - i0;
nG = max(i0) + 2;
acc = @(v) accumarray(i0 + 1, Wt .* (1 - f1) .* v, [nG 1]) + ...
           accumarray(i0 + 2, Wt .* f1 .* v, [nG 1]);
den = acc(ones(size(x)));
sp.u = uMin + (0:nG-1)' / revCols;
sp.x = acc(x) ./ den;   sp.w = acc(Wd) ./ den;
sp.x(den == 0) = NaN;   sp.w(den == 0) = NaN;
sp.nViews = accumarray(i0 + 1, 1, [nG 1]);
sp.rs = eval_spiral(sp.u, coef);
sp.pitch = pitch;
sp.ecc = struct('A', coef.A, 'B', coef.B, 'e', hypot(coef.A, coef.B));
sp.turns = max(n) - min(n) + 1;

chain.theta = 2*pi * sp.u';
c = (sp.rs + sp.x)';
chain.centre = c;
chain.outer = c + sp.w' / 2;                       % outer edge = larger radius
chain.inner = c - sp.w' / 2;
chain.nodes = [];
end

function [rs, coef] = silent_spiral(u, R, Wt)
% Least squares: piecewise-linear trend in u (knot every turn) + e cos,
% e sin. Fitted on every 8th reading (plenty, and keeps it small) via the
% normal equations, with Huber reweighting (the music is the "noise" here)
k0 = floor(min(u));  k1 = ceil(max(u));
knots = k0:k1;
nk = numel(knots);
s = 1:8:numel(u);
us = u(s);  Rs = R(s);  ws = Wt(s);
j = min(max(floor(us - k0) + 1, 1), nk - 1);
t = us - knots(j)';
n = numel(us);
A = sparse([1:n, 1:n]', [j; j + 1], [1 - t; t], n, nk);
A = [A, sparse(cos(2*pi*us)), sparse(sin(2*pi*us))];
wr = ones(n, 1);
for it = 1:3
    ww = ws .* wr;
    D = spdiags(ww, 0, n, n);
    a = full((A' * D * A + 1e-9 * speye(nk + 2)) \ (A' * (ww .* Rs)));
    e = Rs - A * a;
    sc = 1.4826 * median(abs(e));
    wr = min(1, 2 * sc ./ max(abs(e), eps));
end
coef.knots = knots;  coef.val = a(1:nk);  coef.A = a(nk + 1);  coef.B = a(nk + 2);
coef.slope = median(diff(coef.val));
rs = eval_spiral(u, coef);
end

function rs = eval_spiral(u, coef)
k0 = coef.knots(1);  nk = numel(coef.knots);
j = min(max(floor(u - k0) + 1, 1), nk - 1);
t = u - coef.knots(j)';
v = coef.val(:);
rs = (1 - t) .* v(j) + t .* v(j + 1) + coef.A * cos(2*pi*u) + coef.B * sin(2*pi*u);
end
