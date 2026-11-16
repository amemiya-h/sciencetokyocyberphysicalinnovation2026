function y = resample_fft(x, fs1, fs2)
%RESAMPLE_FFT  Band-limited resampling of a column signal by zero-padding
%   (or truncating) its spectrum.
x = x(:); N1 = numel(x); N2 = round(N1 * fs2 / fs1);
X = fft(x);
Y = zeros(N2, 1);
h = floor((min(N1, N2) - 1) / 2);
Y(1:h+1) = X(1:h+1);
Y(end-h+1:end) = X(end-h+1:end);
y = real(ifft(Y)) * N2 / N1;
end
