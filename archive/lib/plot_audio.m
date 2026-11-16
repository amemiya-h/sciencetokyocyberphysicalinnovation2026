function fig = plot_audio(ref, est, tWindow)
%PLOT_AUDIO  Recovered vs true band-passed signal, in time and frequency.
%   fig = PLOT_AUDIO(ref, est) takes two structs from centreline_to_audio
%   (true centreline and estimate) and plots the output-rate signals.
%   fig = PLOT_AUDIO(ref, est, tWindow) limits the waveform plot to
%   tWindow = [tStart tEnd] (s); the spectrum always uses the whole signal.
%
%   The spectrum is an averaged periodogram (Hann window, 4096 samples or
%   the signal length if shorter), in dB.

if nargin < 3
    tWindow = [0, ref.tOut(end)];
end

fig = figure('Color', 'w');

subplot(2, 1, 1);
inWin = ref.tOut >= tWindow(1) & ref.tOut <= tWindow(2);
plot(ref.tOut(inWin)*1e3, ref.audio(inWin), 'k-', 'LineWidth', 1.5);
hold on;
plot(est.tOut(inWin)*1e3, est.audio(inWin), 'r--', 'LineWidth', 1.2);
hold off;
xlabel('Time (ms)');
ylabel('Signal');
title(sprintf('Band-passed signal at %.0f kHz', ref.fs/1e3));
legend('True', 'Recovered', 'Location', 'best');
grid on;

subplot(2, 1, 2);
[f, pRef] = averaged_spectrum(ref.audio, ref.fs);
[~, pEst] = averaged_spectrum(est.audio, ref.fs);
[~, pErr] = averaged_spectrum(est.audio - ref.audio, ref.fs);
semilogx(f, pRef, 'k-', f, pEst, 'r--', f, pErr, 'b-');
xlim([max(f(2), 20), ref.fs/2]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Spectrum');
legend('True', 'Recovered', 'Error', 'Location', 'best');
grid on;
end

function [f, pdB] = averaged_spectrum(s, fs)
n = min(4096, numel(s));
w = 0.5 - 0.5*cos(2*pi*(0:n-1)'/n);   % Hann
nSeg = floor(numel(s) / n);
segs = reshape(s(1:nSeg*n), n, nSeg) .* w;
P = mean(abs(fft(segs)).^2, 2) / sum(w.^2);
f = (0:floor(n/2))' * fs / n;
pdB = 10*log10(P(1:numel(f)) / n + eps);
end
