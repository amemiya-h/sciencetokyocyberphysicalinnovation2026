function Pp = est_spacing(F, guess)
%EST_SPACING  Groove spacing (rows) of an image from the spectrum of its
%   column profiles, searched within 0.6..1.6 x guess.
B = double(F) - mean(F(:));
B = B - movmean(B, round(3 * guess), 1);
S = mean(abs(fft(B, [], 1)).^2, 2);
h = size(B, 1); f = (0:h-1)' / h;
band = f > 1 / (1.6 * guess) & f < 1 / (0.6 * guess);
idx = find(band);
[~, j] = max(S(idx)); j = idx(j);
if j > 1 && j < h
    d = 0.5 * (S(j - 1) - S(j + 1)) / (S(j - 1) - 2 * S(j) + S(j + 1));
else
    d = 0;
end
Pp = 1 / ((j - 1 + d) / h);
end
