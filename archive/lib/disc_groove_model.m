function gm = disc_groove_model(sig, fs, scene, Rref, tRef, nPad)
%DISC_GROOVE_MODEL  The whole spiral groove of a record side, cut from audio.
%   gm = DISC_GROOVE_MODEL(sig, fs, scene, Rref, tRef, nPad) cuts the audio
%   (see audio_to_groove) and lays it on a spiral. The spacing between
%   turns varies as on a real lathe: each turn clears its neighbour by at
%   least scene.minLand, using a look-ahead of one revolution (or a fixed
%   scene.pitch if ~scene.variablePitch). nPad revolutions of silent
%   groove are added before and after the music, so turns next to the
%   music in a wide field of view still exist.
%
%   Inputs
%     sig, fs   audio (n x 1 or n x 2), sample rate (Hz)
%     Rref      radius (um) of the groove at time tRef (s, from the start of sig)
%     nPad      revolutions of silence added at each end
%
%   Output struct gm, all at the audio rate, time 0 = start of the padding
%     fs, T      sample rate (Hz), revolution period (s)
%     lat, vert  lateral / vertical groove motion (um)
%     Rrest      radius of the unmodulated groove (um), decreasing in time
%     tMusic     time (s) at which sig starts

T = 60 / scene.rpm;
[lat, vert] = audio_to_groove(sig, fs, scene);
pad = round(nPad * T * fs);
lat = [zeros(pad, 1); lat; zeros(pad, 1)];
vert = [zeros(pad, 1); vert; zeros(pad, 1)];

nT = round(T * fs);
if scene.variablePitch
    nEnv = max(1, round(scene.envelopeWindow * fs));
    env = envelope_max(lat, nEnv) + envelope_max(vert, nEnv);
    envNext = [env(nT+1:end); repmat(env(end), nT, 1)];
    need = 2*scene.depth*tand(scene.includedAngle/2) + scene.minLand + env + envNext;
    gap = envelope_max(need, nT);     % max over about +/- 1 revolution
else
    gap = scene.pitch * ones(size(lat));
end
Rrest = -cumsum(gap) / nT;            % inward by one gap per revolution

iRef = round((tRef + pad/fs) * fs) + 1;
gm.Rrest = Rrest - Rrest(iRef) + Rref;
gm.lat = lat;
gm.vert = vert;
gm.fs = fs;
gm.T = T;
gm.tMusic = pad / fs;
end
