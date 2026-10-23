function N = surface_normals(Z, dx, dy)
%SURFACE_NORMALS  Unit surface normals of a height map.
%   N = SURFACE_NORMALS(Z, dx, dy) returns an nRows x nCols x 3 array of
%   unit normals [Nx, Ny, Nz]. Columns of Z run along x, rows along y.
%   dx, dy are the grid spacings, in the same units as Z.

[dZdx, dZdy] = gradient(Z, dx, dy);
N = cat(3, -dZdx, -dZdy, ones(size(Z)));
N = N ./ sqrt(sum(N.^2, 3));
end
