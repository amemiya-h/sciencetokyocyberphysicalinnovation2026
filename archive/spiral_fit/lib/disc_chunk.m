function [Hb, gb, cols, cost, n] = disc_chunk(M, C, sig, hk, I)
%DISC_CHUNK  Robust normal equations of the groove readings for one chunk.
%   C = [x y k n]: full-res px about the image centre, frame index, and the
%   turn number n fixed by the chain (method A4). Residual rho = Psi - n
%   (turns, not wrapped, so the fit cannot slip a turn), scaled by sig;
%   Huber loss with threshold hk (A5). Returns the block Hb = J'WJ/sig^2 and
%   gb = J'W rho/sig^2 on the parameters cols (global indices, see
%   DISC_PACK): the poses of the chunk's frames, the pitch and distortion.
x = double(C(:, 1)); y = double(C(:, 2)); k = double(C(:, 3)); n0 = double(C(:, 4));
n = numel(x);
E = disc_eval(M, x, y, k);
rho = E.psi - n0;
rs = abs(rho) / sig;
w = ones(n, 1);
big = rs > hk;
w(big) = hk ./ rs(big);
cost = sum(0.5 * rs(~big).^2) + sum(hk * rs(big) - 0.5 * hk^2);
Hb = []; gb = []; cols = [];
if nargout < 2, return; end
fi = M.fidx(k);
[fu, ~, q] = unique(fi);
nq = numel(fu);
p = M.p;
Jp = zeros(n, 3 * nq);
for i = 1:nq
    r = find(q == i);
    Jp(r, 3 * i - 2) = -p * E.Gx(r);
    Jp(r, 3 * i - 1) = -p * E.Gy(r);
    Jp(r, 3 * i) = -M.s / (2 * pi);
end
Jb = (b3int((M.r0 - M.rC') / M.rh) - b3int(E.Z)) * M.rh;
nd = size(M.dpow, 1);
Jal = zeros(n, nd);
for m = 1:nd
    Jal(:, m) = p * E.Gy .* E.xn.^M.dpow(m, 1) .* E.yn.^M.dpow(m, 2);
end
J = [Jp, Jb, Jal];
pc = zeros(3 * nq, 1);
pc(1:3:end) = I.dcx(fu); pc(2:3:end) = I.dcy(fu); pc(3:3:end) = I.dth(fu);
cols = [pc; I.beta; I.alpha];
Hb = J' * (J .* (w / sig^2));
gb = J' * (w .* rho / sig^2);
end
