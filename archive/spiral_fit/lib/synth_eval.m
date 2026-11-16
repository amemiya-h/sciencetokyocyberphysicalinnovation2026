function [psi, r, P, phi, X] = synth_eval(T, k, x, y)
%SYNTH_EVAL  True spiral phase at image points (x, y about the image centre) of frame k.
xn = x / (T.W / 2); yn = y / (T.H / 2);
d = zeros(size(x));
for i = 1:size(T.dpow, 1)
    d = d + T.alpha(i) * xn.^T.dpow(i, 1) .* yn.^T.dpow(i, 2);
end
Dx = T.p * (x - T.c(k, 1));
Dy = T.p * (y + d - T.c(k, 2));
r = hypot(Dx, Dy);
phi = atan2(Dy, Dx) - T.theta(k);
psi = interp1(T.rg, T.Ng, r) + T.s * phi / (2 * pi);
P = interp1(T.rg, T.Pg, r);
t = T.theta(k);
X = cat(3, cos(t) * Dx + sin(t) * Dy, -sin(t) * Dx + cos(t) * Dy);
end
