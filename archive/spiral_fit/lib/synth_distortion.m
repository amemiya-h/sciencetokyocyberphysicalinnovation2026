function d = synth_distortion(T, x, y)
%SYNTH_DISTORTION  True lens distortion (px) of the synthetic test at image points.
xn = x / (T.W / 2); yn = y / (T.H / 2);
d = zeros(size(x));
for i = 1:size(T.dpow, 1)
    d = d + T.alpha(i) * xn.^T.dpow(i, 1) .* yn.^T.dpow(i, 2);
end
end
