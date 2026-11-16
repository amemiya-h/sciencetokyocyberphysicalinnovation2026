function audio = noiseFilter(audio, sampleRate, noise)
%NOISEFILTER  Turn each frequency down by as much as it is noise.
%
%   audio = groove.audio.noiseFilter(audio, sampleRate, noise)
%
%   audio   samples in rows, one column per channel
%   noise   report.noise from groove.processFreehand, which holds the
%           measured power of the scan (groove + noise) and of the noise
%           alone at every frequency
%
%   Gain at each frequency = share of the power there that is groove:
%   (total - noise) / total. Where the scan is clean the gain is 1; where
%   it is all noise the gain is 0; in between it falls smoothly. This is
%   the Wiener filter. Compared with a fixed low-pass it keeps the treble
%   that is really there and needs no cutoff to be chosen.

% Smooth the measured spectra a little, then the gain curve.
kernel = ones(1, 9) / 9;
total  = conv(noise.totalPower, kernel, 'same');
random = conv(noise.noisePower, kernel, 'same');
gainCurve = max(0, 1 - random ./ max(total, eps));
gainCurve = conv(gainCurve, kernel, 'same');

% Apply as a fixed filter: overlapping tapered blocks, each scaled in the
% frequency domain, added back together.
block = 4096;
hop   = block / 2;
taper = (0.5 - 0.5 * cos(2*pi * (0:block - 1) / block)).';      % sums to 1 at 50% overlap
frequency = [0:block/2, -block/2 + 1:-1].' * sampleRate / block;
gain = interp1(noise.frequencyHz, gainCurve, abs(frequency), 'linear', 0);

numSamples = size(audio, 1);
padded = [zeros(hop, size(audio, 2)); audio; zeros(block, size(audio, 2))];
output = zeros(size(padded));
for start = 1:hop:size(padded, 1) - block + 1
    piece = start:start + block - 1;
    spectrum = fft(padded(piece, :) .* taper);
    output(piece, :) = output(piece, :) + real(ifft(spectrum .* gain));
end
audio = output(hop + (1:numSamples), :);
end
