function [v, I] = disc_pack(M)
%DISC_PACK  Parameter vector of the disc model and its index map.
v = [M.dcx; M.dcy; M.dth; M.beta; M.alpha];
n = [numel(M.dcx), numel(M.dcy), numel(M.dth), numel(M.beta), numel(M.alpha)];
names = {'dcx', 'dcy', 'dth', 'beta', 'alpha'};
o = 0;
for i = 1:numel(n)
    I.(names{i}) = o + (1:n(i))';
    o = o + n(i);
end
I.n = o;
end
