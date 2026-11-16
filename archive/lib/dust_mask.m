function mask = dust_mask(xs, ys, dust, seed)
%DUST_MASK  Random dust particles on the record surface.
%   mask = DUST_MASK(xs, ys, dust, seed): logical map on the grid xs
%   (1 x nCols) by ys (nRows x 1), both in um, true where a particle
%   covers the surface. dust.perMm2 sets the density and dust.radius =
%   [rMin rMax] the size range (um, log-uniform). seed makes the dust
%   repeatable for the same patch of record.

mask = false(numel(ys), numel(xs));
area = (xs(end) - xs(1)) * (ys(end) - ys(1)) * 1e-6;     % mm^2
state = rng;
rng(seed);
n = poissrnd_simple(dust.perMm2 * area);
cx = xs(1) + (xs(end) - xs(1)) * rand(n, 1);
cy = ys(1) + (ys(end) - ys(1)) * rand(n, 1);
r = exp(log(dust.radius(1)) + diff(log(dust.radius)) * rand(n, 1));
rng(state);
dx = xs(2) - xs(1);
dy = ys(2) - ys(1);
for p = 1:n
    ci = find(abs(xs - cx(p)) <= r(p) + dx);
    ri = find(abs(ys - cy(p)) <= r(p) + dy);
    [XX, YY] = meshgrid(xs(ci), ys(ri));
    mask(ri, ci) = mask(ri, ci) | ((XX - cx(p)).^2 + (YY - cy(p)).^2 <= r(p)^2);
end
end

function n = poissrnd_simple(lambda)
% Poisson sample without the Statistics Toolbox
if lambda > 50
    n = max(0, round(lambda + sqrt(lambda) * randn));
    return;
end
n = 0;
p = exp(-lambda);
F = p;
u = rand;
while u > F
    n = n + 1;
    p = p * lambda / n;
    F = F + p;
end
end
