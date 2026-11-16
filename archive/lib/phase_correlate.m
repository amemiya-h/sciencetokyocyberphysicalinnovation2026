function [dx, dy, resp] = phase_correlate(Fa, Fb)
%PHASE_CORRELATE  Shift between two images from their Fourier transforms.
%   [dx, dy, resp] = PHASE_CORRELATE(Fa, Fb) takes fft2 of two equally
%   sized (windowed) images a and b and returns the shift of b's content
%   relative to a's, b(y, x) ~ a(y - dy, x - dx), in pixels (sub-pixel,
%   x to the right, y down). resp is the height of the correlation peak:
%   near 1 for the same content, near 0 for unrelated images.

R = conj(Fa) .* Fb;
R = R ./ max(abs(R), eps);
c = real(ifft2(R));
[H, W] = size(c);
[resp, k] = max(c(:));
[iy, ix] = ind2sub([H, W], k);
% sub-pixel: parabola through the peak and its (wrapped) neighbours
ym = c(mod(iy - 2, H) + 1, ix);  yp = c(mod(iy, H) + 1, ix);
xm = c(iy, mod(ix - 2, W) + 1);  xp = c(iy, mod(ix, W) + 1);
dy = iy - 1 + vertex(ym, resp, yp);
dx = ix - 1 + vertex(xm, resp, xp);
% wrap to -N/2..N/2
if dy > H/2, dy = dy - H; end
if dx > W/2, dx = dx - W; end
end

function d = vertex(m, c, p)
den = m - 2*c + p;
if den >= 0, d = 0; else, d = 0.5 * (m - p) / den; end
end
