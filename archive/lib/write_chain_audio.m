function best = write_chain_audio(chains, T, audioOpts, runsDir, tag)
%WRITE_CHAIN_AUDIO  Play back groove chains and write them all as WAVs.
%   best = WRITE_CHAIN_AUDIO(chains, T, audioOpts, runsDir, tag) writes to
%   runsDir:
%     <tag>_stereo.wav, <tag>_mono.wav   the loudest of the long chains
%         (the longest is often the silent lead-in groove at the edge)
%     <tag>_chains/chain_NNN_r<radius>mm_<length>s.wav   every chain of at
%         least 0.2 s, all with the same gain so their levels compare
%     <tag>_all.wav       all of those, outer groove first, 0.2 s apart
%     <tag>_all_eq.wav    the same made listenable: rumble below 50 Hz
%                         removed and the level set by the bulk of the
%                         signal (rare spikes rounded off) instead of by
%                         the largest spike
%   T is the time of one revolution (s); best is the chain played.

dur = arrayfun(@(c) (c.theta(end) - c.theta(1)) / (2*pi) * T, chains);
if ~exist(runsDir, 'dir'), mkdir(runsDir); end
cand = find(dur >= 0.5 * max(dur));
cand = cand(1:min(10, end));
lev = zeros(size(cand));
fprintf('  long chains [chain, seconds, mean radius mm, level dB]:\n');
for i = 1:numel(cand)
    ai = chain_to_audio(chains(cand(i)), T, audioOpts);
    lev(i) = 20*log10(sqrt(mean(ai.mono.^2)) + eps);
    fprintf('    %3d  %5.2f  %7.3f  %6.1f\n', cand(i), dur(cand(i)), ...
        mean(chains(cand(i)).centre, 'omitnan') / 1000, lev(i));
end
[~, ib] = max(lev);
best = cand(ib);
a = chain_to_audio(chains(best), T, audioOpts);
scale = 0.9 / max(abs([a.left; a.right]));
audiowrite(fullfile(runsDir, [tag '_stereo.wav']), scale*[a.left, a.right], a.fs);
audiowrite(fullfile(runsDir, [tag '_mono.wav']), scale*a.mono, a.fs);
fprintf('Wrote %s_stereo.wav and %s_mono.wav from chain %d (%.2f s)\n', tag, tag, ...
    best, numel(a.mono) / a.fs);

% Everything: every chain of at least 0.2 s as its own WAV (same gain
% for all, so levels compare), and all of them in one file, outer groove
% first, with 0.2 s of silence between chains
chainDir = fullfile(runsDir, [tag '_chains']);
if ~exist(chainDir, 'dir'), mkdir(chainDir); end
old = dir(fullfile(chainDir, 'chain_*.wav'));
for f = 1:numel(old), delete(fullfile(chainDir, old(f).name)); end
keep = find(dur >= 0.2);
rad = arrayfun(@(c) mean(c.centre, 'omitnan'), chains(keep));
[~, o] = sort(rad, 'descend');
keep = keep(o);
A = cell(1, numel(keep));
if isempty(keep), keep = 1; rad = mean(chains(1).centre, 'omitnan'); o = 1; end
for i = 1:numel(keep)
    A{i} = chain_to_audio(chains(keep(i)), T, audioOpts);
end
peak = max(cellfun(@(x) max(abs([x.left; x.right])), A));
gap = zeros(round(0.2 * A{1}.fs), 2);
allLR = [];
for i = 1:numel(keep)
    LR = 0.9 / peak * [A{i}.left, A{i}.right];
    audiowrite(fullfile(chainDir, sprintf('chain_%03d_r%.3fmm_%.1fs.wav', keep(i), ...
        rad(o(i)) / 1000, dur(keep(i)))), LR, A{i}.fs);
    allLR = [allLR; LR; gap];   %#ok<AGROW>
end
audiowrite(fullfile(runsDir, [tag '_all.wav']), allLR, A{1}.fs);
audiowrite(fullfile(runsDir, [tag '_all_eq.wav']), listenable(allLR, A{1}.fs), A{1}.fs);
fprintf('Wrote %d chains to %s_chains/ and all of them (%.1f s) to %s_all.wav (+ _all_eq.wav)\n', ...
    numel(keep), tag, size(allLR, 1) / A{1}.fs, tag);

end

function y = listenable(x, fs)
% High-pass at 50 Hz (FFT, smooth edge), then level: 99.5% of samples
% within half scale, the rest rounded off by tanh
n = size(x, 1);
f = (0:n-1)' / n * fs;
f = min(f, fs - f);                       % two-sided
g = 1 ./ (1 + (50 ./ max(f, eps)).^8);    % 4th-order-like high-pass
y = real(ifft(fft(x) .* g));
a = abs(y(any(x ~= 0, 2), :));
a = sort(a(:));
ref = a(max(1, round(0.995 * numel(a))));
y = tanh(0.5 * y / max(ref, eps));
end
