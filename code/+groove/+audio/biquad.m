function [b, a] = biquad(kind, cutoffHz, sampleRate)
%BIQUAD  Second-order Butterworth low-pass or high-pass filter.
%
%   [b, a] = groove.audio.biquad('lowpass',  cutoffHz, sampleRate)
%   [b, a] = groove.audio.biquad('highpass', cutoffHz, sampleRate)
%
%   Coefficients are for use with filter(b, a, x). Written out by hand so
%   the library needs no toolbox.

w = 2*pi * cutoffHz / sampleRate;
alpha = sin(w) / sqrt(2);          % Q = 1/sqrt(2): Butterworth
switch lower(kind)
    case 'lowpass'
        b = [(1 - cos(w))/2,  1 - cos(w),   (1 - cos(w))/2];
    case 'highpass'
        b = [(1 + cos(w))/2, -(1 + cos(w)), (1 + cos(w))/2];
    otherwise
        error('groove:audio:badFilter', 'Unknown filter kind ''%s''.', kind);
end
a = [1 + alpha, -2*cos(w), 1 - alpha];
b = b / a(1);
a = a / a(1);
end
