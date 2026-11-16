function snd = music_sound(B, S, outBase)
%MUSIC_SOUND  Binned groove displacement to sound (method B5).
%   snd = MUSIC_SOUND(B, S, outBase): gaps up to music.gapFillMax_ms are
%   filled band-limited (Papoulis-Gerchberg: alternate a low-pass at
%   music.bandHigh_Hz with putting the measured bins back), longer ones play
%   as silence; velocity = dx/dt; RIAA
%   playback (if music.riaa); band-pass music.bandLow_Hz..bandHigh_Hz;
%   resample to output.fsOut_Hz. Mono = centre, stereo L/R = inner/outer
%   wall when music.leftWall is 'inner' (swapped otherwise). Writes
%     <outBase>_mono.wav, _stereo.wav   raw: float, 1.0 = vMax (physicalLimits)
%     <outBase>_mono_eq.wav, _stereo_eq.wav   listenable: high-pass
%       output.eqHighpass_Hz, level from the output.levelPercentile
%       percentile, tanh soft limit; never normalised to the peak.
fb = S.music.binRate_Hz; fo = S.output.fsOut_Hz;
X = [B.x, B.xIn, B.xOut];
miss = isnan(X(:, 1));
% gaps
d = diff([0; miss; 0]);
gs = find(d == 1); ge = find(d == -1) - 1;
gl = ge - gs + 1;
maxFill = round(S.music.gapFillMax_ms * 1e-3 * fb);
silent = false(size(miss));
for i = 1:numel(gs)
    if gl(i) > maxFill || gs(i) == 1 || ge(i) == numel(miss)
        silent(gs(i):ge(i)) = true;
    end
end
t = (1:size(X, 1))';
fill = miss & ~silent;
nf = size(X, 1); fq = [0:floor(nf / 2), -ceil(nf / 2) + 1:-1]' / nf * fb;
lp = abs(fq) <= S.music.bandHigh_Hz;
for j = 1:3
    v = X(:, j); ok = ~isnan(v);
    v(~ok) = interp1(t(ok), v(ok), t(~ok), 'linear', 'extrap');
    if any(fill)
        for it = 1:30
            vf = real(ifft(fft(v) .* lp));
            v(fill) = vf(fill);
        end
    end
    X(:, j) = v;
end
snd.missShare = mean(miss); snd.silentShare = mean(silent);
snd.filledShare = mean(miss & ~silent);
% velocity (m/s)
V = [zeros(1, 3); diff(X)] * fb * 1e-6;
V(silent | [false; silent(1:end-1)], :) = 0;
if S.music.riaa
    for j = 1:3, V(:, j) = riaa_playback(V(:, j), fb); end
end
for j = 1:3
    v = V(:, j);
    for rep = 1:2
        [bh, ah] = biquad_design('high', S.music.bandLow_Hz, fb, 1 / sqrt(2));
        v = filter(bh, ah, v);
        if S.music.bandHigh_Hz < fb / 2
            [bl, al] = biquad_design('low', S.music.bandHigh_Hz, fb, 1 / sqrt(2));
            v = filter(bl, al, v);
        end
    end
    V(:, j) = v;
end
Y = zeros(round(size(V, 1) * fo / fb), 3);
for j = 1:3, Y(:, j) = resample_fft(V(:, j), fb, fo); end
Y = Y / S.physicalLimits.vMax_m_s;
if strcmpi(S.music.leftWall, 'inner'), st = Y(:, [2, 3]); else, st = Y(:, [3, 2]); end
audiowrite([outBase '_mono.wav'], single(Y(:, 1)), fo, 'BitsPerSample', 32);
audiowrite([outBase '_stereo.wav'], single(st), fo, 'BitsPerSample', 32);
% listenable
[bh, ah] = biquad_design('high', S.output.eqHighpass_Hz, fo, 1 / sqrt(2));
E = filter(bh, ah, [Y(:, 1), st]);
lev = pctl(abs(E(:, 1)), S.output.levelPercentile);
g = 0.5 / max(lev, eps);
E = E * g;
if S.output.softLimit, E = tanh(E); else, E = max(-1, min(1, E)); end
audiowrite([outBase '_mono_eq.wav'], E(:, 1), fo, 'BitsPerSample', 16);
audiowrite([outBase '_stereo_eq.wav'], E(:, 2:3), fo, 'BitsPerSample', 16);
snd.duration_s = size(Y, 1) / fo;
snd.rawRms = sqrt(mean(Y(:, 1).^2)); snd.eqGain = g;
snd.files = {[outBase '_mono.wav'], [outBase '_stereo.wav'], [outBase '_mono_eq.wav'], [outBase '_stereo_eq.wav']};
fprintf('sound: %.1f s; bins empty %.2f%% (interpolated %.2f%%, silent %.2f%%); raw rms %.4f of vMax; eq gain %.3g\n', ...
    snd.duration_s, 100 * snd.missShare, 100 * snd.filledShare, 100 * snd.silentShare, snd.rawRms, g);
fprintf('wrote %s_{mono,stereo}{,_eq}.wav\n', outBase);
end
