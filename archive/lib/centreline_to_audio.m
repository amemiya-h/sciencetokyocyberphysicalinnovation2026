function a = centreline_to_audio(xCentre, dy, opts)
%CENTRELINE_TO_AUDIO  Play back a groove centreline as band-limited audio.
%   a = CENTRELINE_TO_AUDIO(xCentre, dy, opts) converts distance along the
%   groove into time through the groove speed. With opts.riaa it then does
%   what a magnetic cartridge and phono stage do: takes the stylus
%   velocity and applies RIAA de-emphasis. Without it, the displacement
%   itself is the signal. The result is band-passed to the audible range
%   and resampled to an audio sample rate.
%
%   The band-pass is also the continuity step for the edge tracker: row-to-
%   row jitter in the detected centre lies far above 20 kHz and is removed.
%
%   Inputs
%     xCentre  nRows x 1 lateral displacement (um), no NaNs
%     dy       sample spacing along the groove (um)
%     opts     struct with fields
%       grooveSpeed  linear groove speed under the stylus (m/s)
%       band         [fLow fHigh] pass band (Hz), e.g. [20 20e3]
%       fsOut        output sample rate (Hz); must exceed 2*fHigh
%       riaa         true for RIAA playback (optional, default false)
%
%   Output (struct a)
%     fsGroove   sample rate implied by dy and grooveSpeed (Hz)
%     t          nRows x 1 time of each groove sample (s)
%     filtered   nRows x 1 band-passed signal at fsGroove (um, or
%                arbitrary units with RIAA)
%     fs         = opts.fsOut (Hz)
%     tOut       time of each output sample (s)
%     audio      band-passed signal resampled to fs
%
%   Notes
%   - The filter zeroes FFT bins outside the band: zero phase, no toolbox
%     needed, but it treats the signal as periodic, so expect ringing at
%     the ends if the first and last samples differ.
%   - The frequency resolution is fsGroove/nRows. For a short groove
%     section it can exceed fLow, in which case the high-pass only removes
%     the mean.

n = numel(xCentre);
a.fsGroove = opts.grooveSpeed / (dy * 1e-6);
a.t = (0:n-1)' / a.fsGroove;

% Band-pass (and RIAA playback) in the frequency domain
f = (0:n-1)' * a.fsGroove / n;
f(f > a.fsGroove/2) = f(f > a.fsGroove/2) - a.fsGroove;   % signed
X = fft(xCentre(:));
inBand = abs(f) >= opts.band(1) & abs(f) <= opts.band(2);
X(~inBand) = 0;
if isfield(opts, 'riaa') && opts.riaa
    X(inBand) = X(inBand) .* (2i*pi*f(inBand)) .* riaa_response(f(inBand));
end
a.filtered = real(ifft(X));

% Resample; the signal is already band-limited below fsOut/2
a.fs = opts.fsOut;
a.tOut = (0 : 1/a.fs : a.t(end))';
a.audio = interp1(a.t, a.filtered, a.tOut, 'linear');
end
