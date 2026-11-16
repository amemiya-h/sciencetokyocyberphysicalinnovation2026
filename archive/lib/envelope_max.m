function e = envelope_max(v, n)
%ENVELOPE_MAX  Running maximum of |v| over a window of about 2n+1 samples.
%   e = ENVELOPE_MAX(v, n). Works in blocks of n samples (block maxima,
%   then the max over each block and its two neighbours), so it is fast
%   for long signals; the window is between 2n and 3n samples wide.

v = abs(v(:));
nb = ceil(numel(v) / n);
vb = [v; zeros(nb*n - numel(v), 1)];
m = max(reshape(vb, n, nb), [], 1)';
m = max([m, [m(2:end); 0], [0; m(1:end-1)]], [], 2);
e = repelem(m, n);
e = e(1:numel(v));
end
