function filled = fillGaps(values)
%FILLGAPS  Replace NaNs in each row by linear interpolation.
%
%   filled = groove.util.fillGaps(values)
%
%   Gaps at either end of a row are filled with the nearest valid value.

filled = values;
positions = 1:size(values, 2);
for row = 1:size(values, 1)
    valid = ~isnan(values(row, :));
    if all(valid) || ~any(valid)
        continue
    end
    filled(row, :) = interp1(positions(valid), values(row, valid), positions, 'linear');
    firstValid = find(valid, 1, 'first');
    lastValid  = find(valid, 1, 'last');
    filled(row, 1:firstValid-1)  = values(row, firstValid);
    filled(row, lastValid+1:end) = values(row, lastValid);
end
end
