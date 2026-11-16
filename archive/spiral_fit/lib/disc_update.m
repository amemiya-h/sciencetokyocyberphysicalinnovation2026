function M = disc_update(M)
%DISC_UPDATE  Per-frame rotation theta_k and spiral centre c_k (K x 2, px)
%   from the start poses and the corrections on the fitted frames.
M.theta = M.theta0 + M.Wk * M.dth;
M.c = M.c0 + M.Wk * [M.dcx, M.dcy];
end
