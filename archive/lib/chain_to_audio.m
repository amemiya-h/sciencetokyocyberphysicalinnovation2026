function a = chain_to_audio(chain, T, audioOpts)
%CHAIN_TO_AUDIO  Play back one stitched groove chain, in stereo.
%   a = CHAIN_TO_AUDIO(chain, T, audioOpts) turns record angle into time
%   (one revolution = T seconds, so the result does not depend on the
%   radius) and plays the groove like a stereo pickup with RIAA playback:
%     mono   from the groove centre (L+R)
%     left   from the inner edge (the inner wall carries the left channel)
%     right  from the outer edge (45/45 stereo)
%   Short gaps are interpolated. audioOpts as for centreline_to_audio
%   (band, fsOut); riaa defaults to true.
%
%   Output struct a: fs, mono, left, right (column vectors, same scale)

if ~isfield(audioOpts, 'riaa'), audioOpts.riaa = true; end
dt = (chain.theta(2) - chain.theta(1)) / (2*pi) * T;
opts = audioOpts;
opts.grooveSpeed = 1e-6 / dt;          % 1 "um" per sample -> sample rate 1/dt
t = (0:numel(chain.theta)-1)';
play = @(x) centreline_to_audio(fill_gaps(t, x(:)), 1, opts);
m = play(chain.centre);
l = play(chain.inner);
r = play(chain.outer);
a.fs = m.fs;
a.mono = m.audio;
a.left = l.audio;
a.right = r.audio;
end
