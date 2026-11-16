function [dx, dy, pk] = phase_corr(A, B, refine)
%PHASE_CORR  Sub-pixel translation of image B relative to image A.
%   [dx, dy, pk] = PHASE_CORR(A, B): the content of A appears in B moved by
%   (dx, dy) px, i.e. B(y, x) ~ A(y - dy, x - dx). pk is the normalised
%   correlation peak (0..1), a match quality.
%   The grooves are nearly constant along x, so their energy lies in a thin
%   wedge of spatial frequencies around the ky axis; whitened, they would
%   dominate and pin only the motion across the grooves. That wedge
%   (|kx| < 0.15 |ky| + 2 bins, about 8.5 deg either side) is removed, so
%   the match comes from the wiggles, dust and scratches, which pin the
%   motion along the groove too. A soft low-pass damps pixel noise.
%   A window fixed on both images pulls the estimate towards zero shift
%   (about 0.2% here), so by default a second pass correlates only the
%   overlapping parts (cropped by the integer shift) and adds the small
%   residual shift.
if nargin < 3, refine = true; end
[dx, dy, pk] = pc1(A, B);
if refine
    ix = round(dx); iy = round(dy);
    [h, w] = size(A);
    if abs(ix) < w / 2 && abs(iy) < h / 2
        ra = max(1, 1 - iy):min(h, h - iy); ca = max(1, 1 - ix):min(w, w - ix);
        [rx, ry, pk] = pc1(A(ra, ca), B(ra + iy, ca + ix));
        if abs(rx) < 2 && abs(ry) < 2
            dx = ix + rx; dy = iy + ry;
        end
    end
end
end

function [dx, dy, pk] = pc1(A, B)
A = prep(A); B = prep(B);
[h, w] = size(A);
ky = ifftshift((0:h-1)' - floor(h / 2)) / h;
kx = ifftshift((0:w-1) - floor(w / 2)) / w;
keep = abs(kx) >= 0.15 * abs(ky) + 2 / w;
wt = keep .* exp(-(kx.^2 + ky.^2) / (2 * 0.2^2));
X = fft2(B) .* conj(fft2(A));
X = wt .* X ./ max(abs(X), 1e-9 * max(abs(X(:))));
c = real(ifft2(X)) / sum(wt(:)) * numel(wt);
[pk, i] = max(c(:));
[iy, ix] = ind2sub([h, w], i);
sy = sub(c(mod(iy - 2, h) + 1, ix), pk, c(mod(iy, h) + 1, ix));
sx = sub(c(iy, mod(ix - 2, w) + 1), pk, c(iy, mod(ix, w) + 1));
dy = wrapidx(iy - 1 + sy, h);
dx = wrapidx(ix - 1 + sx, w);
end

function I = prep(I)
I = double(I);
[h, w] = size(I);
wy = 0.5 - 0.5 * cos(2 * pi * (0:h-1)' / (h - 1));
wx = 0.5 - 0.5 * cos(2 * pi * (0:w-1) / (w - 1));
I = (I - mean(I(:))) .* (wy * wx);
end

function s = sub(a, b, c)
den = a - 2 * b + c;
if den >= 0, s = 0; else, s = 0.5 * (a - c) / den; end
s = max(-0.5, min(0.5, s));
end

function d = wrapidx(d, n)
if d >= n / 2, d = d - n; end
end
