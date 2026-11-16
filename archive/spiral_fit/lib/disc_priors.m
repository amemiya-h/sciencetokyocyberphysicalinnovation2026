function [Hp, gp, cp] = disc_priors(M, S)
%DISC_PRIORS  Prior terms of the fit (quadratic, in units of the data cost).
%   All widths come from settings.json: P(r) changes by
%   record.pitchChangeMax_umPerTurn per turn (first and second differences
%   of g = 1/P between knots, scaled by the knot spacing, so the prior means
%   the same for any record.pitchKnotTurns) and stays near pitch_um (loosely,
%   half of it); distortion within spiralFit.distortionMax_px. The poses have
%   no prior: they are held by the groove readings, motion links and overlaps
%   (apart from the gauge below).
[v, I] = disc_pack(M);
Hp = sparse(I.n, I.n); gp = zeros(I.n, 1); cp = 0;
P0 = S.record.pitch_um;
nb = numel(M.beta);
kt = S.record.pitchKnotTurns;
dPturn = S.record.pitchChangeMax_umPerTurn;
for ord = 1:2
    Dk = diff(eye(nb), ord);
    sdd = dPturn * kt / P0^2;               % change of g per knot step
    Hp(I.beta, I.beta) = Hp(I.beta, I.beta) + sparse(Dk' * Dk / sdd^2);
    gp(I.beta) = gp(I.beta) + Dk' * Dk * M.beta / sdd^2;
    cp = cp + 0.5 * sum((Dk * M.beta).^2) / sdd^2;
end
[Hp, gp, cp] = diag_prior(Hp, gp, cp, I.beta, v, 1 / P0, 0.5 / P0);
[Hp, gp, cp] = diag_prior(Hp, gp, cp, I.alpha, v, 0, S.spiralFit.distortionMax_px);
% gauge: a common rotation of all frames is exchanged with a common radial
% shift of the centres (the phase cannot tell them apart), so the mean
% correction of theta is held within spiralFit.gaugeTheta_rad
nf = numel(I.dth);
u = zeros(1, I.n); u(I.dth) = 1 / nf;
sg = S.spiralFit.gaugeTheta_rad;
res = (u * v) / sg;
Hp = Hp + sparse(u' * u) / sg^2; gp = gp + u' * res / sg; cp = cp + 0.5 * res^2;
end

function [Hp, gp, cp] = diag_prior(Hp, gp, cp, ix, v, t, s)
Hp(ix, ix) = Hp(ix, ix) + speye(numel(ix)) / s^2;
gp(ix) = gp(ix) + (v(ix) - t) / s^2;
cp = cp + 0.5 * sum((v(ix) - t).^2) / s^2;
end
