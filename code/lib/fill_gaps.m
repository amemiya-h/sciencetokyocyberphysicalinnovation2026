function xf = fill_gaps(y, xs)
%FILL_GAPS  Fill NaN rows of a tracked signal.
%   xf = FILL_GAPS(y, xs) linearly interpolates NaN entries of xs over the
%   positions y, and holds the nearest valid value beyond the first and
%   last detection. y and xs are column vectors of equal length.

valid = ~isnan(xs);
if nnz(valid) < 2
    error('fill_gaps:tooFew', ['Too few valid edge pairs detected. ', ...
        'Inspect the intensity profile and adjust parameters.']);
end

xf = interp1(y(valid), xs(valid), y, 'linear');
ends = isnan(xf);
xf(ends) = interp1(y(valid), xs(valid), y(ends), 'nearest', 'extrap');
end
