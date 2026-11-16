function y = denoise_audio(x, fs, opts)
%DENOISE_AUDIO  Light clean-up: remove clicks, then reduce hiss.
%   y = DENOISE_AUDIO(x, fs, opts) works on each column (channel) of x.
%   Clicks (a tracking glitch makes a short spike in groove velocity) are
%   found where the signal jumps far above its local typical level, and
%   bridged by interpolation. Then the hiss: the noise spectrum is estimated as a low percentile of the power in
%   each frequency over time (music comes and goes, steady hiss stays),
%   then every short-time spectrum is scaled by a gain that removes about
%   that much power (Wiener-like), never below opts.floor so the result
%   does not sound "watery". Stretches of exact silence (gaps between
%   chains) are ignored when estimating the noise.
%
%   opts fields (defaults in brackets)
%     win      window length, samples [2048]
%     pct      percentile used as the noise level [20]
%     over     over-subtraction factor [2]
%     floor    smallest gain [0.1] (-20 dB)
%     smooth   gain smoothing over time, 0..1 [0.5]
%     clickK   click threshold, times the local median level [6]
%     clickPad samples bridged on each side of a click [96] (2 ms at 48 kHz)

if nargin < 3, opts = struct(); end
def = struct('win', 2048, 'pct', 20, 'over', 2, 'floor', 0.1, 'smooth', 0.5, ...
             'clickK', 6, 'clickPad', 96);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end
for pass = 1:2
    x = declick(x, opts.clickK, opts.clickPad, round(0.25 * fs));
end
n = opts.win;  hop = n / 4;
w = 0.5 - 0.5 * cos(2*pi*(0:n-1)' / n);          % periodic Hann
L = size(x, 1);
nF = ceil((L + n) / hop) + 1;
y = zeros(size(x));
for c = 1:size(x, 2)
    xp = [zeros(n, 1); x(:, c); zeros(nF*hop, 1)];
    idx = (0:n-1)' + (0:nF-1) * hop + 1;
    S = fft(xp(idx) .* w);
    S = S(1:n/2+1, :);
    P = abs(S).^2;
    active = sum(P, 1) > 1e-6 * max(sum(P, 1));
    Ps = sort(P(:, active), 2);
    N = Ps(:, max(1, round(opts.pct/100 * size(Ps, 2))));
    G = max(1 - opts.over * N ./ max(P, eps), opts.floor);
    for t = 2:size(G, 2)
        G(:, t) = opts.smooth * G(:, t-1) + (1 - opts.smooth) * G(:, t);
    end
    S = S .* G;
    S = [S; conj(S(end-1:-1:2, :))];
    fr = real(ifft(S)) .* w;
    out = zeros(size(xp));
    for t = 1:nF
        out(idx(:, t)) = out(idx(:, t)) + fr(:, t);
    end
    out = out / (sum(w.^2) / hop);                % overlap-add gain
    y(:, c) = out(n+1 : n+L);
end
end

function x = declick(x, K, pad, blk)
% Bridge samples whose size is far above the local median size
L = size(x, 1);
a = max(abs(x), [], 2);
nb = ceil(L / blk);
med = zeros(1, nb);
for b = 1:nb
    seg = a((b-1)*blk + 1 : min(b*blk, L));
    seg = seg(seg > 0);
    if isempty(seg), med(b) = NaN; else, med(b) = median(seg); end
end
med(isnan(med)) = inf;
centres = ((1:nb) - 0.5) * blk;
ref = interp1(centres, med, (1:L)', 'linear', 'extrap');
bad = a > K * ref;
if ~any(bad), return; end
k = find(bad);
mask = false(L, 1);
for d = -pad:pad
    j = k + d;  j = j(j >= 1 & j <= L);
    mask(j) = true;
end
good = find(~mask);
if numel(good) < 2, return; end
for c = 1:size(x, 2)
    x(mask, c) = interp1(good, x(good, c), find(mask), 'linear', 0);
end
end
