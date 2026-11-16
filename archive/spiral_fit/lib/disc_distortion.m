function d = disc_distortion(M, x, y)
%DISC_DISTORTION  Lens distortion across the grooves at image points (px).
xn = x / M.xs; yn = y / M.ys;
d = zeros(size(x));
for m = 1:size(M.dpow, 1)
    d = d + M.alpha(m) * xn.^M.dpow(m, 1) .* yn.^M.dpow(m, 2);
end
end
