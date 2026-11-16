function rows = centreRows(edges)
%CENTREROWS  Mean row of each groove near the middle of the frame.
%
%   rows = groove.mosaic.centreRows(edges)
%
%   Used to tell grooves apart and to know how far each is from the image
%   centre. Averaged over the central eighth of the width so the audio
%   wiggle and the groove curvature have little effect.

width  = size(edges.top, 2);
middle = round(width * 7/16):round(width * 9/16);
centre = (double(edges.top(:, middle)) + double(edges.bottom(:, middle))) / 2;
valid  = ~isnan(centre);
centre(~valid) = 0;
rows = sum(centre, 2) ./ max(sum(valid, 2), 1);
rows(~any(valid, 2)) = NaN;
end
