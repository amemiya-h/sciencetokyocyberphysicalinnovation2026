function prepared = prepareFrame(edges)
%PREPAREFRAME  Turn a frame's grooves into fingerprints for matching.
%
%   prepared = groove.mosaic.prepareFrame(edges)
%
%   For every groove: its centre line with tilt and curvature removed (what
%   is left is the audio wiggle), faded out toward the frame sides, and its
%   Fourier transform. Grooves with too many gaps are blanked so they
%   cannot vote.

centre = (double(edges.top) + double(edges.bottom)) / 2;
[numGrooves, width] = size(centre);
missing = isnan(centre);
usable  = mean(missing, 2) < 0.05;

filled  = centre;
filled(missing) = 0;
rowMean = sum(filled, 2) ./ max(sum(~missing, 2), 1);
filled  = filled + missing .* rowMean;        % gaps take the groove's mean

x = (1:width) - (width + 1) / 2;
basis  = [x(:).^2, x(:), ones(width, 1)];
wiggle = filled - (filled * pinv(basis).') * basis.';   % remove a parabola per groove
wiggle(missing) = 0;
wiggle(~usable, :) = 0;
taper  = 0.5 - 0.5 * cos(2*pi * (0:width - 1) / (width - 1));
wiggle = wiggle .* taper;

prepared.rows     = edges.rows(:);
prepared.width    = width;
prepared.spectrum = fft(wiggle, 2^nextpow2(2 * width), 2);
prepared.energy   = sum(wiggle.^2, 2);
end
