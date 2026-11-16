function [H, gv, cost, r] = disc_links(M, Lk, hk, I)
%DISC_LINKS  Motion-link and overlap residuals of the pose fit (method A5).
%   Residual per link (px): c_b + Rot(theta_b - theta_a)(q - c_a) - q - m,
%   scaled by Lk.sig, Huber loss with threshold hk. Frames that are not
%   fitted take their pose from the two neighbouring fitted frames.
%   Returns the sparse normal equations (H, gv), the cost and r (nL x 2, px).
nL = numel(Lk.a);
ca = M.c(Lk.a, :); cb = M.c(Lk.b, :);
da = M.theta(Lk.b) - M.theta(Lk.a);
cs = cos(da); sn = sin(da);
v = Lk.q - ca;
Rv = [cs .* v(:, 1) - sn .* v(:, 2), sn .* v(:, 1) + cs .* v(:, 2)];
Rp = [-sn .* v(:, 1) - cs .* v(:, 2), cs .* v(:, 1) - sn .* v(:, 2)];
r = cb + Rv - Lk.q - Lk.m;
z = r ./ Lk.sig;
az = abs(z);
big = az > hk;
cost = sum(0.5 * az(~big).^2) + sum(hk * az(big) - 0.5 * hk^2);
H = sparse(I.n, I.n); gv = zeros(I.n, 1);
if nargout < 2, return; end
wH = ones(nL, 2); wH(big) = hk ./ az(big);
cols = zeros(nL, 12);
J = zeros(2, 12, nL);
Rp1 = Rp(:, 1); Rp2 = Rp(:, 2);
for s = 1:2
    ia = M.fj(Lk.a, s); wa = M.fw(Lk.a, s);
    ib = M.fj(Lk.b, s); wb = M.fw(Lk.b, s);
    oa = 3 * (s - 1); ob = 6 + 3 * (s - 1);
    cols(:, oa + (1:3)) = [I.dcx(ia), I.dcy(ia), I.dth(ia)];
    cols(:, ob + (1:3)) = [I.dcx(ib), I.dcy(ib), I.dth(ib)];
    J(1, oa + 1, :) = reshape(-wa .* cs, 1, 1, nL);  J(1, oa + 2, :) = reshape(wa .* sn, 1, 1, nL);
    J(2, oa + 1, :) = reshape(-wa .* sn, 1, 1, nL);  J(2, oa + 2, :) = reshape(-wa .* cs, 1, 1, nL);
    J(1, oa + 3, :) = reshape(-wa .* Rp1, 1, 1, nL); J(2, oa + 3, :) = reshape(-wa .* Rp2, 1, 1, nL);
    J(1, ob + 1, :) = reshape(wb, 1, 1, nL);         J(2, ob + 2, :) = reshape(wb, 1, 1, nL);
    J(1, ob + 3, :) = reshape(wb .* Rp1, 1, 1, nL);  J(2, ob + 3, :) = reshape(wb .* Rp2, 1, 1, nL);
end
Js = J ./ reshape(Lk.sig', 2, 1, nL);
Jw = Js .* reshape(wH', 2, 1, nL);
Hb = pagemtimes(Js, 'transpose', Jw, 'none');                    % 12 x 12 x nL
gb = pagemtimes(Js, 'transpose', reshape((wH .* z)', 2, 1, nL), 'none');   % 12 x 1 x nL
ii = repmat(permute(cols, [2 3 1]), 1, 12, 1);
jj = repmat(permute(cols, [3 2 1]), 12, 1, 1);
H = sparse(ii(:), jj(:), Hb(:), I.n, I.n);
gv = accumarray(cols(:), reshape(reshape(gb, 12, nL)', [], 1), [I.n, 1]);
end
