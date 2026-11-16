function [lat, vert, info] = audio_to_groove(sig, fs, scene)
%AUDIO_TO_GROOVE  Cut an audio signal into groove motion, as a lathe would.
%   [lat, vert, info] = AUDIO_TO_GROOVE(sig, fs, scene)
%
%   The audio is band-limited to scene.band. With scene.riaa, each
%   channel drives its wall with RIAA pre-emphasised VELOCITY, so the
%   displacement is the integral of that. In 45/45 stereo each wall moves
%   at 45 degrees: lateral motion = (L + R)/sqrt(2), vertical motion =
%   (L - R)/sqrt(2). Everything is scaled so the largest lateral
%   excursion is scene.peakLateral.
%
%   Inputs
%     sig          n x 1 (mono) or n x 2 (stereo) audio
%     fs           sample rate (Hz)
%     scene        see default_scene (band, riaa, stereo, peakLateral)
%
%   Outputs, at the audio sample rate (evaluate between samples with
%   groove_motion_at)
%     lat    lateral displacement of the groove centre (um)
%     vert   upward displacement of the groove bottom (um), 0 if mono
%     info   peakVelocity (cm/s), peakVertical (um)

if size(sig, 2) == 1
    sig = [sig, sig];
end
sig = sig - mean(sig, 1);
n = size(sig, 1);
nfft = 2^nextpow2(2*n);
f = (0:nfft-1)' * fs / nfft;
f(f > fs/2) = f(f > fs/2) - fs;                 % signed frequencies

X = fft(sig, nfft);
inBand = abs(f) >= scene.band(1) & abs(f) <= scene.band(2);
X(~inBand, :) = 0;
if scene.riaa
    X(inBand, :) = X(inBand, :) ./ riaa_response(f(inBand)) ./ (2i*pi*f(inBand));
end
w = real(ifft(X));
w = w(1:n, :);

lat = (w(:, 1) + w(:, 2)) / sqrt(2);
vert = (w(:, 1) - w(:, 2)) / sqrt(2);
if ~scene.stereo
    vert(:) = 0;
end
k = scene.peakLateral / max(abs(lat));
lat = k * lat;
vert = k * vert;

info.peakVelocity = max(abs(diff(lat))) * fs * 1e-4;   % um/s -> cm/s
info.peakVertical = max(abs(vert));
end
