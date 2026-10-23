function lit = cast_shadow(Z, dx, l)
%CAST_SHADOW  Points of a height map that can see a light.
%   lit = CAST_SHADOW(Z, dx, l) marches from every point towards the
%   light direction l (unit vector, record -> light) across the columns
%   of Z (spacing dx, um) and returns false where the surface blocks it.
%   Only the across-groove (x) component is traced: along the groove the
%   surface changes slowly, so shadows along y are ignored. Beyond the
%   edges of Z the surface is assumed to be land (z = 0).

lit = true(size(Z));
lxy = hypot(l(1), l(2));
if lxy < 1e-6 || abs(l(1)) < 0.3*lxy
    return;
end
rise = l(3) / abs(l(1));                 % height gained per um along x
nShift = ceil((max(Z(:)) - min(Z(:))) / (rise*dx));
nCols = size(Z, 2);
for k = 1:min(nShift, nCols - 1)
    if l(1) > 0
        ahead = [Z(:, k+1:end), zeros(size(Z, 1), k)];
    else
        ahead = [zeros(size(Z, 1), k), Z(:, 1:end-k)];
    end
    lit = lit & ~(ahead > Z + k*dx*rise);
end
end
