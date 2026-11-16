function g = read_grooves_polar(P, cam, opts)
%READ_GROOVES_POLAR  Read every groove's centre and width off an unwarped image.
%   g = READ_GROOVES_POLAR(P, cam, opts) takes an image from unwarp_frame
%   (silent grooves run along the rows). It finds the grooves ("lanes")
%   from the brightness averaged along the rows, then reads each column
%   of each lane, i.e. straight across the groove, by fitting the groove
%   profile model of fit_groove_profiles:
%       m(y) = L - (L - D) [Phi((y - c + w/2)/s) - Phi((y - c - w/2)/s)]
%              + b exp(-(y - c)^2 / (2 tau^2))
%   c, w per column; L, D slowly varying along each lane; blur s and the
%   bottom-line height b shared by the whole image. All columns of all
%   lanes are solved at once (2 x 2 Gauss-Newton per column), so the cost
%   is a few passes over the pixels. Columns that the model does not
%   explain, or that jump in a way a cut groove cannot (opts.maxJump), are
%   marked bad rather than smoothed over.
%
%   opts fields (defaults in brackets)
%     pitch     groove spacing (um) [120]
%     width     groove width (um) [64]
%     iters     Gauss-Newton iterations [6]
%     maxJump   largest believable change of c between neighbouring
%               columns (px) [0.6]: a cut groove slants by at most ~0.1
%               (lateral speed / groove speed), i.e. ~0.1 px per px,
%               plus noise
%
%   Output struct g (nL lanes, W columns)
%     row0    nL x 1 lane centre row (silent groove)
%     c, w    nL x W centre row and width (px); NaN where unusable
%     ok      nL x W logical, columns judged good
%     res     nL x W residual rms of the fit (brightness)
%     sigma, bump   shared wall blur (px) and bottom-line height

if nargin < 3, opts = struct(); end
def = struct('pitch', 120, 'width', 64, 'iters', 6, 'maxJump', 0.6);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end
[H, W] = size(P);
pp = opts.pitch / cam.pixel;
w0 = opts.width / cam.pixel;
h = round(0.5 * pp);

% 1. Lanes: dark minima of the brightness averaged along the rows
m = mean_omitnan_rows(P);
k = ceil(2); gk = exp(-0.5 * ((-3*k:3*k)' / k).^2);  gk = gk / sum(gk);
ms = conv(m, gk, 'same');
lo = prctile_vec(ms, 10);  hi = prctile_vec(ms, 90);
cand = find(ms(2:end-1) < ms(1:end-2) & ms(2:end-1) <= ms(3:end)) + 1;
cand = cand(ms(cand) < lo + 0.5 * (hi - lo));
cand = cand(cand > h + 1 & cand < H - h);
% keep the darkest minimum within 0.6 pitch
[~, o] = sort(ms(cand));
keep = [];
for i = o(:)'
    if all(abs(cand(i) - cand(keep)) > 0.6 * pp), keep(end+1) = i; end   %#ok<AGROW>
end
row0 = sort(cand(keep));
nL = numel(row0);
g.row0 = row0;
[g.c, g.w, g.res] = deal(nan(nL, W));
g.ok = false(nL, W);
g.sigma = NaN;  g.bump = NaN;
if nL == 0, return; end

% 2. Starting values per column: darkness centroid, window following it
C = repmat(row0, 1, W);
yy = (-h:h)';
for pass = 1:2
    Cs = round(movmean_rows(C, 15));
    [Y, R] = windows(P, Cs, yy);
    Lp = max(Y, [], 1);  dark = max(Lp - Y, 0);
    dark(isnan(dark)) = 0;
    C = reshape(sum(dark .* R, 1) ./ max(sum(dark, 1), eps), nL, W);
end
Cs = round(movmean_rows(C, 15));
[Y, R] = windows(P, Cs, yy);                       % (2h+1) x (nL*W)
valid = all(~isnan(Y), 1);
Y(:, ~valid) = 0;
c = C(:)';  w = repmat(w0, 1, nL*W);
% land and groove brightness, smoothed along each lane
L = smooth_lane(prctile_cols(Y, 90), nL, W, valid);
D = smooth_lane(prctile_cols(Y, 8), nL, W, valid);
s = 1.5;  b = 0;  tau = max(1, 0.12 * w0);
wt = double(repmat(valid, 2*h + 1, 1));
for it = 1:opts.iters
    [M, dc, dw, ds, db] = model(R, c, w, L, D, s, b, tau);
    E = Y - M;
    sc = 1.4826 * median(abs(E(wt > 0)));
    wr = wt .* min(1, 2 * sc ./ max(abs(E), eps));      % robust weights
    a11 = sum(wr .* dc.^2, 1);  a12 = sum(wr .* dc .* dw, 1);  a22 = sum(wr .* dw.^2, 1);
    b1 = sum(wr .* dc .* E, 1);  b2 = sum(wr .* dw .* E, 1);
    det = a11 .* a22 - a12.^2;
    det(abs(det) < eps) = eps;
    stc = (a22 .* b1 - a12 .* b2) ./ det;
    stw = (a11 .* b2 - a12 .* b1) ./ det;
    c = c + max(min(stc, 2), -2);
    w = min(max(w + max(min(stw, 2), -2), 0.4 * w0), 1.8 * w0);
    G = [ds(:), db(:)] .* sqrt(wr(:));
    sg = (G' * G + 1e-9 * eye(2)) \ (G' * (sqrt(wr(:)) .* E(:)));
    s = min(max(s + sg(1), 0.3), 0.4 * h);
    b = max(b + sg(2), 0);
end
[M, dc] = model(R, c, w, L, D, s, b, tau);
res = sqrt(sum(wt .* (Y - M).^2, 1) ./ max(sum(wt, 1), 1));
g.c = reshape(c, nL, W);  g.w = reshape(w, nL, W);
g.res = reshape(res, nL, W);
g.sigma = s;  g.bump = b;

% 3. Judge columns: inside the image, explained by the model, a believable
%    width, and no jump a cut groove cannot make
ok = reshape(valid, nL, W);
rv = g.res(ok);
ok = ok & g.res < 3 * median(rv);
wv = g.w(ok);
ok = ok & abs(g.w - median(wv)) < 0.35 * median(wv);
ok = ok & abs(g.c - reshape(Cs, nL, W)) < h - 0.5 * w0;   % stayed in its window
for i = 1:nL
    ci = g.c(i, :);  ci(~ok(i, :)) = NaN;
    ref = movmedian_nan(ci, 9);
    ok(i, :) = ok(i, :) & abs(ci - ref) < opts.maxJump * 3;
end
g.ok = ok;
g.c(~ok) = NaN;  g.w(~ok) = NaN;
end

% ---------------------------------------------------------------------
function [Y, R] = windows(P, Cs, yy)
[H, W] = size(P);
nL = size(Cs, 1);
R = Cs(:)' + yy;                                   % rows, (2h+1) x (nL*W)
cols = repmat(kron(1:W, ones(1, nL)), numel(yy), 1);
inside = R >= 1 & R <= H;
Y = nan(size(R));
Y(inside) = P(sub2ind([H W], R(inside), cols(inside)));
end

function [M, dc, dw, ds, db] = model(R, c, w, L, D, s, b, tau)
a = (R - c + w/2) / s;
z = (R - c - w/2) / s;
Pa = 0.5 * erfc(-a / sqrt(2));  Pz = 0.5 * erfc(-z / sqrt(2));
pa = exp(-a.^2/2) / sqrt(2*pi);  pz = exp(-z.^2/2) / sqrt(2*pi);
e = exp(-(R - c).^2 / (2*tau^2));
K = L - D;
M = L - K .* (Pa - Pz) + b * e;
dc = K / s .* (pa - pz) + b * e .* (R - c) / tau^2;
dw = -K / (2*s) .* (pa + pz);
ds = K / s .* (a .* pa - z .* pz);
db = e;
end

function v = smooth_lane(v, nL, W, valid)
V = reshape(v, nL, W);  ok = reshape(valid, nL, W);
V(~ok) = NaN;
V = movmean_rows(V, 129);
V(isnan(V)) = mean(v(valid));
v = V(:)';
end

function M = movmean_rows(M, n)
% moving mean along each row, ignoring NaN
k = ones(1, n);
ok = ~isnan(M);
Z = M;  Z(~ok) = 0;
S = conv2(Z, k, 'same');  N = conv2(double(ok), k, 'same');
M = S ./ N;
end

function v = movmedian_nan(x, n)
h = floor(n/2);
v = nan(size(x));
xp = [nan(1, h), x, nan(1, h)];
X = zeros(n, numel(x));
for d = 0:n-1, X(d+1, :) = xp(1+d : numel(x)+d); end
X = sort(X, 1);                       % NaN sort last
cnt = sum(~isnan(X), 1);
for j = find(cnt > 0)
    v(j) = X(ceil(cnt(j)/2), j);
end
end

function m = mean_omitnan_rows(P)
ok = ~isnan(P);  Z = P;  Z(~ok) = 0;
m = sum(Z, 2) ./ max(sum(ok, 2), 1);
end

function q = prctile_cols(Y, p)
Ys = sort(Y, 1);
q = Ys(max(1, round(p/100 * size(Y, 1))), :);
end

function q = prctile_vec(v, p)
v = sort(v(~isnan(v)));
q = v(max(1, round(p/100 * numel(v))));
end
