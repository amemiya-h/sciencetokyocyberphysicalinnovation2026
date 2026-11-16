function y = resampleTo(x, rateIn, rateOut)
%RESAMPLETO  Change the sample rate of a recording.
%
%   y = groove.audio.resampleTo(x, rateIn, rateOut)
%
%   x  samples in rows, one column per channel. rateIn need not be a whole
%      number; a hand-turned scan gives whatever rate one revolution
%      happened to produce.
%
%   Works through the Fourier transform: the spectrum is cut or zero-padded
%   to the new length, so nothing above the lower Nyquist limit survives.
%   Processed in overlapping blocks to keep memory modest.

block   = 2^18;                 % input samples per block
overlap = 2^12;                 % discarded at each block edge
ratio   = rateOut / rateIn;
numOut  = round(size(x, 1) * ratio);
y = zeros(numOut, size(x, 2));

start = 1;
while start <= size(x, 1)
    first = max(1, start - overlap);
    last  = min(size(x, 1), start + block - 1 + overlap);
    piece = x(first:last, :);
    n = size(piece, 1);
    m = round(n * ratio);
    spectrum = fft(piece);
    keep = floor(min(n, m) / 2);
    resized = zeros(m, size(x, 2));
    resized(1:keep, :)             = spectrum(1:keep, :);
    resized(end - keep + 2:end, :) = spectrum(end - keep + 2:end, :);
    piece = real(ifft(resized)) * (m / n);

    % Output samples this block is responsible for.
    outFirst = round((start - 1) * ratio) + 1;
    outLast  = min(numOut, round((start + block - 1) * ratio));
    source   = (outFirst:outLast) - round((first - 1) * ratio);
    source   = min(max(source, 1), m);
    y(outFirst:outLast, :) = piece(source, :);
    start = start + block;
end
end
