function s = score_chain(chain, a, truth, T, audioOpts)
%SCORE_CHAIN  Compare a recovered groove chain with the simulation's truth.
%   s = SCORE_CHAIN(chain, a, truth, T, audioOpts) finds which turn of the
%   true spiral the chain is (from its radius), fits a small time offset,
%   and compares the edges and the stereo audio.
%   truth: from forward_keyence_ring (gm, phi); a: chain_to_audio output.
%
%   Output struct s
%     turn, lag    turn index and fitted time offset (s)
%     rmsCentre    centre-line error above ~50 Hz (um); slower parts such
%                  as the off-centre disc's radial swing are excluded
%     snrMono, snrLeft, snrRight   audio SNR against a perfect pickup (dB)
%     snrSide      SNR of the stereo difference L-R (dB): how well the
%                  stereo information itself is recovered

gm = truth.gm;
at = @(v, t) groove_motion_at(v, gm.fs, t);
Rat = @(t) interp1(gm.Rrest, min(max(1 + t*gm.fs, 1), numel(gm.Rrest)), 'linear');
t0 = (chain.theta + truth.phi(1)) / (2*pi) * T;

iv = find(~isnan(chain.centre), 1);
ms = -80:80;
tm = t0(iv) + ms*T;
okm = tm > 0 & tm < numel(gm.lat)/gm.fs;
R = nan(size(ms));
R(okm) = Rat(tm(okm)) + at(gm.lat, tm(okm));
[~, k] = min(abs(R - chain.centre(iv)));
% The radius alone can be off by up to the disc's offset from the rig
% axis, so try the neighbouring turns too and pick by the wiggle.
lags = (-300:5:300) * 1e-6;
x = chain.centre;
okx = ~isnan(x);
dt = (chain.theta(2) - chain.theta(1)) / (2*pi) * T;
win = max(3, round(0.01 / dt));                 % ~10 ms: keeps > ~50 Hz
best = inf;
for mm = ms(max(1, k-2) : min(numel(ms), k+2))
    for q = 1:numel(lags)
        t = t0 + mm*T + lags(q);
        d = x - (Rat(t) + at(gm.lat, t));
        d = highpass(d, win);
        e = sqrt(mean(d(okx).^2));
        if e < best
            best = e;  s.turn = mm;  s.lag = lags(q);
        end
    end
end
s.rmsCentre = best;

% True edges at those times, through the same playback
t = t0 + s.turn*T + s.lag;
c = Rat(t) + at(gm.lat, t);
hw = truth.depth - at(gm.vert, t);
tc = chain;
tc.centre = c;  tc.inner = c - hw;  tc.outer = c + hw;
b = chain_to_audio(tc, T, audioOpts);
snr = @(est, ref) 10*log10(sum(ref.^2) / sum((est - ref).^2));
s.snrMono = snr(a.mono, b.mono);
s.snrLeft = snr(a.left, b.left);
s.snrRight = snr(a.right, b.right);
s.snrSide = snr(a.left - a.right, b.left - b.right);
end

function y = highpass(x, win)
% x minus its moving average over win samples (NaNs ignored)
ok = ~isnan(x);
x0 = x;  x0(~ok) = 0;
k = ones(1, win);
m = conv(x0, k, 'same') ./ max(conv(double(ok), k, 'same'), 1);
y = x - m;
end
