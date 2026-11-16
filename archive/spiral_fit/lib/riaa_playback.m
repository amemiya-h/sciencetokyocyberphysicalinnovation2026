function y = riaa_playback(x, fs)
%RIAA_PLAYBACK  RIAA playback (de-emphasis) of a groove velocity signal.
%   H(s) = (1 + s*318us) / ((1 + s*3180us) (1 + s*75us)), bilinear
%   transform with the 75 us pole prewarped; unity gain at 1 kHz.
t1 = 3180e-6; t2 = 318e-6; t3 = 75e-6;
K = 2 * pi * (1 / (2 * pi * t3)) / tan(pi * (1 / (2 * pi * t3)) / fs);  % prewarp at 2122 Hz
% numerator 1 + s t2, denominator (1 + s t1)(1 + s t3), s = K (1 - z^-1)/(1 + z^-1)
nb = [1 + K * t2, 1 - K * t2];                      % times (1 + z^-1)
num = conv(nb, [1, 1]);
d1 = [1 + K * t1, 1 - K * t1]; d3 = [1 + K * t3, 1 - K * t3];
den = conv(d1, d3);
num = num / den(1); den = den / den(1);
y = filter(num, den, x);
H1k = abs(polyval(num, exp(1i * 2 * pi * 1000 / fs)) / polyval(den, exp(1i * 2 * pi * 1000 / fs)));
y = y / H1k;
end
