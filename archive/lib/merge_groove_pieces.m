function tracks = merge_groove_pieces(tracks, cam, Rcam)
%MERGE_GROOVE_PIECES  Join the pieces of a groove that tracking split up.
%   tracks = MERGE_GROOVE_PIECES(tracks, cam, Rcam) works image by image.
%   Dust, a scratch or a blurred patch can break a groove's track into
%   several pieces, and a chain through the images ends wherever its
%   track does. Every groove runs along the same gentle curve (a circle
%   of radius Rcam about the rig axis, tilted by the camera skew), so
%   each piece is given a "lane": its row with that curve and the common
%   tilt removed. Pieces in the same lane (closer than a fifth of the
%   groove spacing) are the same groove: the longest piece is kept and
%   its missing columns are filled from the others.

W = cam.imageSize(2);
cols = 1:W;
X = (cols - (W + 1)/2) * cam.pixel;
bend = (X.^2 / (2 * Rcam)) / cam.pixel;      % rows grow downward
for k = 1:numel(tracks)
    t = tracks{k};
    n = size(t.outer, 1);
    if n < 2, continue; end
    d = (t.outer + t.inner) / 2 - bend;
    cov = mean(~isnan(d), 2);
    % common tilt from the longer pieces
    sl = [];
    for i = find(cov >= 0.5)'
        ok = ~isnan(d(i, :));
        q = polyfit(cols(ok), d(i, ok), 1);
        sl(end+1) = q(1);   %#ok<AGROW>
    end
    if isempty(sl), continue; end
    s = median(sl);
    lane = median_omitnan(d - s * cols, 2);
    [ls, order] = sort(lane);
    spacing = median(diff(ls(cov(order) >= 0.5)));
    if isnan(spacing), continue; end
    tol = 0.2 * spacing;
    % group neighbours in lane order
    grp = cumsum([1; diff(ls) > tol]);
    keepRows = false(n, 1);
    for g = 1:grp(end)
        members = order(grp == g);
        [~, best] = max(cov(members));
        a = members(best);
        for b = members(:)'
            if b == a, continue; end
            fill = isnan(t.outer(a, :)) & ~isnan(t.outer(b, :));
            t.outer(a, fill) = t.outer(b, fill);
            t.inner(a, fill) = t.inner(b, fill);
        end
        keepRows(a) = true;
    end
    t.outer = t.outer(keepRows, :);
    t.inner = t.inner(keepRows, :);
    [~, o] = sort(median_omitnan(t.outer, 2));
    t.outer = t.outer(o, :);  t.inner = t.inner(o, :);
    tracks{k} = t;
end
end
