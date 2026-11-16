function M = disc_unpack(M, v)
%DISC_UNPACK  Put a parameter vector back into the model (see DISC_PACK).
[~, I] = disc_pack(M);
M.dcx = v(I.dcx); M.dcy = v(I.dcy); M.dth = v(I.dth);
M.beta = v(I.beta); M.alpha = v(I.alpha);
M = disc_update(M);
end
