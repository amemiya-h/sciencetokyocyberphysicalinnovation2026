function [period, stepSign, strength] = findRevolution(mosaic, cfg)
%FINDREVOLUTION  Find where the scan comes back round to its start.
%
%   [period, stepSign, strength] = groove.mosaic.findRevolution(mosaic, cfg)
%
%   After one full turn a groove band shows the music its neighbour showed
%   at the start, because the groove is a spiral. So each mosaic row is
%   compared with the row next to it at a large offset; the offset at which
%   they all agree is one revolution.
%
%   period    bins in one revolution
%   stepSign  +1 if moving forward along the mosaic leads to the next row
%             (toward the bottom of the image), -1 if to the previous row
%   strength  height of the correlation peak over the typical level
%
%   Needs a scan of more than one revolution: cfg.mosaic.minOverlapUm of
%   groove must have been seen twice.

[numTracks, numBins] = size(mosaic.top);
centre = (mosaic.top + mosaic.bottom) / 2;
seen   = ~isnan(centre);
used   = find(sum(seen, 2) > 3000).';

% The wiggle: centre line minus its running mean, zero where unseen.
window = ones(1, 301);
transformLength = 2^nextpow2(2 * numBins);
spectrum = zeros(numTracks, transformLength);
for t = used
    values = double(centre(t, :));
    values(~seen(t, :)) = 0;
    runningMean = conv(values, window, 'same') ./ max(conv(double(seen(t, :)), window, 'same'), 1);
    wiggle = (values - runningMean) .* seen(t, :);
    spectrum(t, :) = fft(wiggle, transformLength);
end

% total(L+1) = sum over rows of  wiggle_t(b) * wiggle_{t+1}(b + L)
total = zeros(1, transformLength);
for t = used
    if t < numTracks && any(used == t + 1)
        total = total + real(ifft(conj(spectrum(t, :)) .* spectrum(t + 1, :)));
    end
end

covered = find(any(seen(used, :), 1));
span    = covered(end) - covered(1);
longest  = span - round(cfg.mosaic.minOverlapUm / cfg.camera.pixelSizeUm);
shortest = round(span / 2);
if longest <= shortest
    error('groove:mosaic:noOverlap', 'The scan is too short to contain a full revolution.');
end
lags = shortest:longest;
forward  = total(lags + 1);                     % row t+1 repeats row t later
backward = total(transformLength - lags + 1);   % row t+1 repeats row t earlier

[peakForward,  atForward]  = max(forward);
[peakBackward, atBackward] = max(backward);
if peakForward >= peakBackward
    period = lags(atForward);
    stepSign = -1;        % (t, b) = (t+1, b+period): going forward lands on the row above
    strength = peakForward / median(abs(forward));
else
    period = lags(atBackward);
    stepSign = 1;
    strength = peakBackward / median(abs(backward));
end
end
