function [Gc, dark, blob] = groove_clean(G, Pp, slope, S)
%GROOVE_CLEAN  Preprocessing for groove detection (not for measurement).
%   [Gc, dark, blob] = GROOVE_CLEAN(G, Pp, slope, S). G: grey frame, Pp:
%   normal groove spacing (px), slope: groove direction dy/dx in the image.
%   1. Flatten the lighting: divide by a blur ~3 spacings wide.
%   2. Grooves are long dark bands along the groove direction: a grey-level
%      closing with a line ~1.5 spacings long along that direction fills in
%      dark features that are shorter along it (scratches across the lands,
%      dust specks).
%   3. Dark/light: below the midpoint of the local land and groove levels.
%   4. Dark runs (along a column) taller than (1 + grooveWidthTol) x 2 the
%      groove width are dust blobs, not grooves: blob = true there.
%   Gc is only for deciding what is a groove; positions are measured on G.
[h, w] = size(G);
G = double(G);
s = 3 * Pp;
g = exp(-(-ceil(2 * s):ceil(2 * s)).^2 / (2 * s^2)); g = g / sum(g);
B = conv2(g, g, G, 'same') ./ conv2(g, g, ones(h, w), 'same');
Gn = G ./ max(B, 1);
% straighten along the groove direction (shear rows by the slope), close, unshear
L = 2 * round(0.75 * Pp) + 1;
sh = round(slope * ((1:w) - (w + 1) / 2));
Gs = shear(Gn, -sh);
Gs = movmin(movmax(Gs, L, 2), L, 2);           % closing of brightness = removes short dark features
Gc = shear(Gs, sh);
% dark/light against local levels
win = 2 * round(Pp) + 1;
hi = movmax(Gc, win, 1); lo = movmin(Gc, win, 1);
dark = Gc < (hi + lo) / 2 & (hi - lo) > 0.15;
% dust blobs: dark runs much taller than a groove
wpx = S.record.grooveWidth_um / (S.microscope.pixelAt1x_um / S.microscope.magnification);
maxRun = 2 * (1 + S.record.grooveWidthTol) * wpx;
blob = false(h, w);
d = diff([false(1, w); dark; false(1, w)], 1, 1);
[rs, cs] = find(d == 1); [re, ~] = find(d == -1);
tall = (re - rs) > maxRun;
for i = find(tall)'
    blob(rs(i):re(i) - 1, cs(i)) = true;
end
end

function Y = shear(X, sh)
% shift each column j by sh(j) rows (with edge replication)
[h, w] = size(X);
r = min(h, max(1, (1:h)' - sh(:)'));
Y = X(r + (0:w-1) * h);
end
