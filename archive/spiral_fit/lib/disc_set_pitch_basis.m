function M = disc_set_pitch_basis(M, rLo, rHi, h, P0)
%DISC_SET_PITCH_BASIS  (Re)build the B-spline basis of g(r) = 1/P(r) on
%   [rLo, rHi] um with knot spacing h um, and set the pitch to P0 um.
nb = ceil((rHi - rLo) / h) + 3;
M.rC = rLo + ((1:nb)' - 2) * h;
M.rh = h;
M.beta = ones(nb, 1) / P0;
end
