function R = disc_residuals(M, chunks, stride)
%DISC_RESIDUALS  Phase residual of every reading (single precision).
%   chunks hold [x y k n], n the turn number fixed by the chain (A4/A5).
%   R.rho = Psi - n (turns, not wrapped), R.psi, R.r (um), R.P = 1/g (um),
%   R.x, R.y, R.k, R.n: the readings. stride > 1 uses every stride-th chunk.
if nargin > 2 && stride > 1, chunks = chunks(1:stride:end); end
nc = numel(chunks);
out = cell(nc, 1);
parfor ci = 1:nc
    C = chunks{ci};
    E = disc_eval(M, C(:, 1), C(:, 2), C(:, 3));
    out{ci} = single([E.psi - double(C(:, 4)), E.psi, E.r, 1 ./ E.g, double(C)]);
end
A = cat(1, out{:});
R.rho = A(:, 1); R.psi = A(:, 2); R.r = A(:, 3); R.P = A(:, 4);
R.x = A(:, 5); R.y = A(:, 6); R.k = A(:, 7); R.n = A(:, 8);
end
