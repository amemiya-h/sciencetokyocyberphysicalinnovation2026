function m = median_omitnan(X, dim)
%MEDIAN_OMITNAN  Median along dim, ignoring NaNs (works in MATLAB and Octave).
%   m = MEDIAN_OMITNAN(X, dim); NaN where a slice has no numbers.
if nargin < 2, dim = 1; end
if dim == 2, X = X.'; end
m = nan(1, size(X, 2));
for k = 1:size(X, 2)
    v = X(~isnan(X(:, k)), k);
    if ~isempty(v), m(k) = median(v); end
end
if dim == 2, m = m.'; end
end
