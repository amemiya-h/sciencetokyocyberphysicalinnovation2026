function sl = est_slope(F)
%EST_SLOPE  Groove direction (rows per column) of an image: the shear that
%   makes the row means most contrasted (grooves straightened along rows).
F = double(F); [h, w] = size(F);
best = -Inf; sl = 0;
for s = -0.1:0.002:0.1
    sh = round(s * ((1:w) - (w + 1) / 2));
    r = min(h, max(1, (1:h)' + sh(:)'));
    v = var(mean(F(r + (0:w-1) * h), 2));
    if v > best, best = v; sl = s; end
end
end
