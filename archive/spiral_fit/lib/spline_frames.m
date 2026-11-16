function B = spline_frames(K, Ks)
%SPLINE_FRAMES  Cubic B-spline basis over frame index, knots every Ks frames.
%   B = SPLINE_FRAMES(K, Ks) is a sparse K x nb matrix; B(k, j) is basis j at
%   frame k. Smooth curves over the video are B * coefficients.
nb = ceil((K - 1) / Ks) + 3;
cj = 1 + ((1:nb) - 2) * Ks;
I = []; J = []; V = [];
k = (1:K)';
for j = 1:nb
    z = (k - cj(j)) / Ks;
    m = abs(z) < 2;
    I = [I; k(m)]; J = [J; j * ones(nnz(m), 1)]; V = [V; b3(z(m))]; %#ok<AGROW>
end
B = sparse(I, J, V, K, nb);
end
