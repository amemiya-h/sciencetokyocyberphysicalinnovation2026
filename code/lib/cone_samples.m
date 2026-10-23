function dirs = cone_samples(axis, halfAngle, spacing)
%CONE_SAMPLES  Unit vectors spread evenly over a cone.
%   dirs = CONE_SAMPLES(axis, halfAngle, spacing) returns directions that
%   cover the cone of half-angle halfAngle (rad) about axis with roughly
%   the given angular spacing (rad), equal solid angle per sample.

n = max(7, ceil(pi * (halfAngle/spacing)^2));
i = (1:n)' - 0.5;
cosT = 1 - (1 - cos(halfAngle)) * i/n;
sinT = sqrt(1 - cosT.^2);
phi = i * pi * (3 - sqrt(5));          % golden angle
local = [sinT.*cos(phi), sinT.*sin(phi), cosT];

a = axis(:)' / norm(axis);
if abs(a(3)) < 0.9, t = [0 0 1]; else, t = [1 0 0]; end
e1 = cross(a, t); e1 = e1 / norm(e1);
e2 = cross(a, e1);
dirs = local(:, 1)*e1 + local(:, 2)*e2 + local(:, 3)*a;
end
