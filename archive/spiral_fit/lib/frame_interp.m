function [W, j, w] = frame_interp(K, fk)
%FRAME_INTERP  Linear interpolation from the fitted frames fk to all K frames.
%   [W, j, w] = FRAME_INTERP(K, fk): W is K x numel(fk) (sparse); frame k
%   takes weights w(k, :) on the fitted frames j(k, :). Frames outside
%   fk(1)..fk(end) hold the nearest fitted frame.
fk = fk(:); nf = numel(fk);
if nf == 1
    j = ones(K, 2); w = [ones(K, 1), zeros(K, 1)];
else
    q = interp1(fk, (1:nf)', (1:K)', 'linear', 'extrap');
    q = min(max(q, 1), nf);
    j0 = min(floor(q), nf - 1);
    t = q - j0;
    j = [j0, j0 + 1]; w = [1 - t, t];
end
k = (1:K)';
W = sparse([k; k], [j(:, 1); j(:, 2)], [w(:, 1); w(:, 2)], K, nf);
end
