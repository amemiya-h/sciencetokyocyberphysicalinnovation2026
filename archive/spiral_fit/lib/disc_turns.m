function [n, renum] = disc_turns(psi, g, sgnY)
%DISC_TURNS  Turn numbers of one frame's readings by counting its grooves.
%   n = DISC_TURNS(psi, g, sgnY): psi spiral phase of the frame's readings
%   (turns), g their groove (track) index in the frame, 1 = top, in order.
%   Tracks are numbered consecutively (sgnY per track); the offset n0 is the
%   one most grooves with a phase within 0.2 turn agree on (method A4).
%   renum: number of tracks whose round(median psi) differs from that.
g = double(g(:)); psi = double(psi(:));
nG = max(g);
pm = accumarray(g, psi, [nG, 1], @median, NaN);
gi = find(~isnan(pm));
cand = round(pm(gi)) - sgnY * (gi - 1);
fr = pm(gi) - round(pm(gi));
good = abs(fr) < 0.2;
if any(good), n0 = mode(cand(good)); else, n0 = mode(cand); end
ng = n0 + sgnY * ((1:nG)' - 1);
n = ng(g);
renum = nnz(round(pm(gi)) ~= ng(gi));
end
