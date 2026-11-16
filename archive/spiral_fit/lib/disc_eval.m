function E = disc_eval(M, x, y, k)
%DISC_EVAL  Spiral phase of image points (method A1-A2).
%   E = DISC_EVAL(M, x, y, k): x, y full-res px about the image centre,
%   k frame index (vectors of equal length). Returns E.psi (turns),
%   E.r (um), E.phi (rad, continuous), E.g = 1/P(r) (1/um), E.Gx, E.Gy
%   (dPsi/dD, 1/um), E.xn, E.yn, E.th, E.Dx, E.Dy, E.d (distortion, px).
x = double(x(:)); y = double(y(:)); k = double(k(:));
xn = x / M.xs; yn = y / M.ys;
d = zeros(size(x));
for m = 1:size(M.dpow, 1)
    d = d + M.alpha(m) * xn.^M.dpow(m, 1) .* yn.^M.dpow(m, 2);
end
p = M.p;
Dx = p * (x - M.c(k, 1));
Dy = p * (y + d - M.c(k, 2));
r = hypot(Dx, Dy);
th = M.theta(k);
phi = atan2(Dy, Dx) - th;
Z = (r - M.rC') / M.rh;                    % n x nb
g = b3(Z) * M.beta;
N = ((b3int((M.r0 - M.rC') / M.rh) - b3int(Z)) * M.rh) * M.beta;
E.psi = N + M.s * phi / (2 * pi);
E.r = r; E.phi = phi; E.g = g; E.th = th;
E.Dx = Dx; E.Dy = Dy; E.d = d; E.xn = xn; E.yn = yn; E.Z = Z;
r2 = r.^2;
E.Gx = -g .* Dx ./ r - M.s / (2 * pi) * Dy ./ r2;
E.Gy = -g .* Dy ./ r + M.s / (2 * pi) * Dx ./ r2;
end
