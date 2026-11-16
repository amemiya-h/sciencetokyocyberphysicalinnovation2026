function M = disc_model_new(S, p, W, H, theta0, R0, fk)
%DISC_MODEL_NEW  Empty disc model (method A1-A2) for a video of K frames.
%   Image coordinates x, y are full-resolution px about the image centre
%   (x right, y down). Frame k maps pixel (x, y) to the disc by
%     D   = p*[x; y + d(x,y)] - p*c_k              (um, image axes)
%     r   = |D|,  phi = atan2(D_y, D_x) - theta_k  (continuous, not wrapped)
%     Psi = N(r) + s*phi/(2 pi),   N(r) = int_r^r0 g,  g = 1/P
%   Every frame has its own pose (c_k, theta_k); no rig is built in. The
%   free parameters sit on the fitted frames fk (every spiralFit.fitFrameStep-th):
%     c = c0 + Wk * [dcx dcy],  theta = theta0 + Wk * dth
%   where c0, theta0 (all frames) come from the chain of DISC_INIT and Wk
%   interpolates the fitted frames' corrections linearly to every frame.
%   d(x,y) = sum alpha_ij xn^i yn^j is the lens distortion across the grooves
%   (px), xn = x/(W/2), yn = y/(H/2); g(r) is a cubic B-spline in r (knots
%   every pitchKnotTurns turns). M.a is a reference axis point (the mean
%   centre after the fit), used by Part B for the axis distance only.
K = numel(theta0);
M.p = p; M.W = W; M.H = H; M.K = K;
M.xs = W / 2; M.ys = H / 2;
M.s = 1;
M.sgnY = 1; if ~S.record.outerEdgeAtTop, M.sgnY = -1; end
M.theta0 = theta0(:); M.R0 = R0;
M.a = [0; M.sgnY * R0];
M.c0 = repmat(M.a', K, 1);
M.fk = fk(:); nf = numel(fk);
[M.Wk, M.fj, M.fw] = frame_interp(K, fk);
M.fidx = zeros(K, 1); M.fidx(fk) = 1:nf;
M.dcx = zeros(nf, 1); M.dcy = zeros(nf, 1); M.dth = zeros(nf, 1);
[PX, PY] = ndgrid(S.microscope.distortionPowersX(:), S.microscope.distortionPowersY(:));
M.dpow = [PX(:), PY(:)];
M.alpha = zeros(size(M.dpow, 1), 1);
P0 = S.record.pitch_um;
M = disc_set_pitch_basis(M, R0 * p - 0.6 * H * p - 2000, R0 * p + 0.6 * H * p + 2000, ...
    S.record.pitchKnotTurns * P0, P0);
M.r0 = round(R0 * p);
M = disc_update(M);
end
