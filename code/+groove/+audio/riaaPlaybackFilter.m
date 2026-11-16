function [b, a] = riaaPlaybackFilter(sampleRate)
%RIAAPLAYBACKFILTER  The standard RIAA playback (de-emphasis) curve.
%
%   [b, a] = groove.audio.riaaPlaybackFilter(sampleRate)
%
%   Records are cut with bass reduced and treble boosted. This filter
%   undoes that. It is the analogue curve with time constants 3180, 318
%   and 75 microseconds, converted with the bilinear transform and scaled
%   to unity gain at 1 kHz. It expects groove velocity as its input.

t1 = 3180e-6;  t2 = 318e-6;  t3 = 75e-6;
k = 2 * sampleRate;

%            1 + s*t2
% H(s) = ---------------------- ,   s -> k (1 - z^-1) / (1 + z^-1)
%        (1 + s*t1) (1 + s*t3)
b = [1 + t2*k,                     2,                   1 - t2*k];
a = [1 + (t1 + t3)*k + t1*t3*k^2,  2 - 2*t1*t3*k^2,     1 - (t1 + t3)*k + t1*t3*k^2];

z = exp(-1i * 2*pi * 1000 / sampleRate);
gainAt1kHz = abs(polyval(fliplr(b), z) / polyval(fliplr(a), z));
b = b / (a(1) * gainAt1kHz);
a = a / a(1);
end
