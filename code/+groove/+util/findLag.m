function [lag, score] = findLag(signal, template)
%FINDLAG  Locate a short signal inside a long one.
%
%   [lag, score] = groove.util.findLag(signal, template)
%
%   lag    index such that signal(lag : lag+numel(template)-1) best matches
%          the template
%   score  normalised correlation of that match, 1 for a perfect copy

signal   = signal(:).';
template = template(:).' - mean(template);
n = numel(signal);
m = numel(template);
assert(n >= m, 'The template is longer than the signal.');

% Correlation at every lag in one go, through the Fourier transform.
fftLength   = 2^nextpow2(n + m);
correlation = real(ifft(fft(signal, fftLength) .* conj(fft(template, fftLength))));
correlation = correlation(1:n - m + 1);

% Normalise by the energy of the signal under the template at each lag.
runningEnergy = cumsum([0, signal.^2]);
windowEnergy  = runningEnergy(m + 1:end) - runningEnergy(1:end - m);
normalised = correlation ./ sqrt(windowEnergy * sum(template.^2) + eps);

[score, lag] = max(normalised);
end
