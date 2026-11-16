function img = synth_render(T, k)
%SYNTH_RENDER  One synthetic frame (uint8) of the truth T (noise from the global RNG).
[x, y] = meshgrid((1:T.W) - (T.W + 1) / 2, (1:T.H) - (T.H + 1) / 2);
[psi, ~, P, phi, X] = synth_eval(T, k, x, y);
n = round(psi);
tm = T.Trev * (n - T.s * phi / (2 * pi));          % music time on this turn
xm = zeros(size(tm));
for i = 1:size(T.tones, 1)
    xm = xm + T.tones(i, 1) * sin(2 * pi * T.tones(i, 2) * tm + T.tones(i, 3));
end
dd = (psi - n) .* P + xm;                           % um from the groove centre, inward +
Phi = @(z) 0.5 * erfc(-z / sqrt(2));
I = T.Lgt - (T.Lgt - T.Drk) * (Phi((dd + T.width / 2) / T.blur) - Phi((dd - T.width / 2) / T.blur)) ...
    + T.bline * exp(-dd.^2 / (2 * T.tau^2));
rr = hypot(X(:, :, 1), X(:, :, 2));
ss = mod(atan2(X(:, :, 2), X(:, :, 1)), 2 * pi) * T.r0;
I = I + double(interp2(T.texS, T.texR, T.tex, ss, rr, 'linear', 0));
I = I .* (1 - 0.15 * ((x / (T.W / 2)).^2 + (y / (T.H / 2)).^2));
I = I + T.noise * randn(size(I));
img = uint8(max(0, min(255, I)));
end
