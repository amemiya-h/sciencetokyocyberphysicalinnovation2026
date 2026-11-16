function mask = disc_defects_mask(xe, ye, scene)
%DISC_DEFECTS_MASK  Dust and scratches fixed to the record surface.
%   mask = DISC_DEFECTS_MASK(xe, ye, scene) marks the grid points covered
%   by dust particles or fine scratches. xe, ye are the record-fixed
%   coordinates (um) of every grid point; they must be an affine function
%   of the grid indices (true for a camera image). Defects are generated
%   per 500 um x 500 um tile of the record with a seed from the tile
%   index, so the same specks appear in every image that overlaps.
%   scene.dust and scene.scratch set density and size.

tile = 500;
mask = false(size(xe));
[nr, nc] = size(xe);
% Affine map grid index -> record coordinates, and its inverse
P0 = [xe(1, 1); ye(1, 1)];
Di = [xe(min(2, nr), 1) - xe(1, 1); ye(min(2, nr), 1) - ye(1, 1)];
Dj = [xe(1, min(2, nc)) - xe(1, 1); ye(1, min(2, nc)) - ye(1, 1)];
M = [Di, Dj];
toIdx = @(px, py) M \ ([px(:)'; py(:)'] - P0) + 1;      % 2 x n (row; col)
step = min(norm(Di), norm(Dj));

ix = floor(min(xe(:)) / tile) : floor(max(xe(:)) / tile);
iy = floor(min(ye(:)) / tile) : floor(max(ye(:)) / tile);
state = rng;
for a = ix
    for b = iy
        rng(mod(a * 73856093 + b * 19349663 + 1234567, 2^31 - 1));
        area = (tile/1000)^2;
        % Dust: discs
        n = poisson_count(scene.dust.perMm2 * area);
        cx = a*tile + tile*rand(n, 1);
        cy = b*tile + tile*rand(n, 1);
        rr = exp(log(scene.dust.radius(1)) + diff(log(scene.dust.radius)) * rand(n, 1));
        for k = 1:n
            mask = mark(mask, toIdx, xe, ye, cx(k), cy(k), cx(k), cy(k), rr(k), step);
        end
        % Scratches: thin straight segments
        n = poisson_count(scene.scratch.perMm2 * area);
        cx = a*tile + tile*rand(n, 1);
        cy = b*tile + tile*rand(n, 1);
        ang = pi * rand(n, 1);
        len = scene.scratch.length(1) + diff(scene.scratch.length) * rand(n, 1);
        wid = scene.scratch.width(1) + diff(scene.scratch.width) * rand(n, 1);
        for k = 1:n
            dx = cos(ang(k)) * len(k)/2;
            dy = sin(ang(k)) * len(k)/2;
            mask = mark(mask, toIdx, xe, ye, cx(k) - dx, cy(k) - dy, ...
                        cx(k) + dx, cy(k) + dy, wid(k)/2, step);
        end
    end
end
rng(state);
end

function mask = mark(mask, toIdx, xe, ye, x1, y1, x2, y2, r, step)
% Mark grid points within r of the segment (x1,y1)-(x2,y2)
c = toIdx([x1 x2 x1 x2] + r*[-1 1 1 -1], [y1 y2 y2 y1] + r*[-1 1 -1 1]);
pad = ceil(r / step) + 2;
i0 = max(1, floor(min(c(1, :))) - pad);  i1 = min(size(mask, 1), ceil(max(c(1, :))) + pad);
j0 = max(1, floor(min(c(2, :))) - pad);  j1 = min(size(mask, 2), ceil(max(c(2, :))) + pad);
if i0 > i1 || j0 > j1
    return;
end
X = xe(i0:i1, j0:j1);
Y = ye(i0:i1, j0:j1);
vx = x2 - x1;  vy = y2 - y1;
L2 = max(vx^2 + vy^2, eps);
t = min(max(((X - x1)*vx + (Y - y1)*vy) / L2, 0), 1);
d2 = (X - x1 - t*vx).^2 + (Y - y1 - t*vy).^2;
mask(i0:i1, j0:j1) = mask(i0:i1, j0:j1) | d2 <= r^2;
end

function n = poisson_count(lambda)
if lambda > 50
    n = max(0, round(lambda + sqrt(lambda) * randn));
    return;
end
n = 0;  p = exp(-lambda);  F = p;  u = rand;
while u > F
    n = n + 1;  p = p * lambda / n;  F = F + p;
end
end
