function [G, stats] = physical_limits(G, cam, Rcam, T, opts)
%PHYSICAL_LIMITS  Reject groove readings a real cut groove cannot produce.
%   [G, stats] = PHYSICAL_LIMITS(G, cam, Rcam, T, opts) checks the grooves
%   read from unwarped images (read_grooves_polar) against two limits of
%   a cut record, applied to each wall (edge) separately, since each wall
%   carries one channel:
%     slope      |d(edge)/d(along groove)| <= vMax / grooveSpeed: the
%                cutter's sideways speed is limited (vMax), the groove
%                passes at 2*pi*r/T
%     curvature  the edge cannot bend tighter than a stylus tip can follow
%                (radius rhoMin), i.e. |d2(edge)/dx2| <= 1/rhoMin
%   Each limit gets a noise allowance (3 x the robust spread of that
%   derivative over the image's good columns), so only readings that are
%   physically impossible, not merely noisy, are rejected. Rejected
%   columns become NaN; overlapping images or interpolation fill them.
%
%   opts fields (defaults in brackets)
%     vMax    largest sideways groove speed (m/s) [0.3]
%     rhoMin  smallest radius of curvature of a groove wall (um) [10]
%
%   stats: fraction of good columns rejected by the slope / curvature test

if nargin < 5, opts = struct(); end
if ~isfield(opts, 'vMax'), opts.vMax = 0.3; end
if ~isfield(opts, 'rhoMin'), opts.rhoMin = 10; end
p = cam.pixel;
H = cam.imageSize(1);
nSlope = 0;  nCurv = 0;  nGood = 0;
for k = 1:numel(G)
    g = G{k};
    c = double(g.c);  w = double(g.w);
    bad = false(size(c));
    for e = [-1, 1]                              % outer, inner wall
        y = c + e * w / 2;                       % edge row (px)
        s = (y(:, [2:end end]) - y(:, [1 1:end-1])) / 2;            % slope, px/px
        s(:, [1 end]) = NaN;
        q = y(:, [2:end end]) - 2*y + y(:, [1 1:end-1]);            % curvature, px/px^2
        q(:, [1 end]) = NaN;
        r = Rcam - (g.row0 - (H + 1)/2) * p;     % lane radius (um)
        sMax = opts.vMax * 1e6 ./ (2*pi*r / T);  % allowed slope per lane
        qMax = p / opts.rhoMin;                  % allowed curvature (px/px^2)
        sv = s(~isnan(s));  qv = q(~isnan(q));
        sN = 3 * 1.4826 * median(abs(sv - median(sv)));
        qN = 3 * 1.4826 * median(abs(qv));
        bs = abs(s) > sMax + sN;
        bq = abs(q) > qMax + qN;
        nSlope = nSlope + nnz(bs & ~bad);
        nCurv = nCurv + nnz(bq & ~bs & ~bad);
        bad = bad | bs | bq;
    end
    % a rejected point also spoils its neighbours' derivatives: widen by 1
    bad = bad | bad(:, [2:end end]) | bad(:, [1 1:end-1]);
    nGood = nGood + nnz(~isnan(c));
    g.c(bad) = NaN;  g.w(bad) = NaN;  g.ok = g.ok & ~bad;
    G{k} = g;
end
stats.slope = nSlope / max(nGood, 1);
stats.curvature = nCurv / max(nGood, 1);
end
