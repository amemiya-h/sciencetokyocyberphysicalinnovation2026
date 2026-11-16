function [t, na] = disc_tangent(M)
%DISC_TANGENT  Unit vector along the groove at the image centre (the way
%   the content moves when theta increases), and the axis distance |a| (px).
na = norm(M.a);
t = [M.a(2); -M.a(1)] / na;
end
