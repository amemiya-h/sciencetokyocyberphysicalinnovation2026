function [tracks, prof] = correct_row_distortion(tracks, cam, Rcam)
%CORRECT_ROW_DISTORTION  Remove the optics' fixed bending of the grooves.
%   [tracks, prof] = CORRECT_ROW_DISTORTION(tracks, cam, Rcam) finds how
%   the optics bend every groove the same way in every image (lens
%   distortion, a slightly tilted view) and takes it out of the edge rows.
%   The bend depends on where in the image a groove is: with real VHX
%   images, grooves near the bottom bend about 2 px more at the sides than
%   grooves near the top. Music differs from groove to groove and frame to
%   frame, so averaged over all grooves of all images, what is left of each
%   groove after removing its own straight line and the bend expected
%   from a circle of radius Rcam is the distortion. It is fitted as a
%   smooth surface d(x, y) = sum a_ij x^i y^j, i = 2..6, j = 0..3 (x, y
%   image position scaled to -1..1); lower powers of x are a groove's own
%   offset and slope and cannot be told apart from it. Left in, the
%   distortion repeats with every image along a chain and plays as a buzz
%   at the image rate; since it differs between grooves at different
%   heights, it also makes overlapping images disagree.
%
%   prof  H x W row correction (px) that was subtracted, or [] if there
%         were too few grooves to estimate it

H = cam.imageSize(1);  W = cam.imageSize(2);
x = ((1:W) - (W + 1)/2) * cam.pixel;
xn = ((1:W) - (W + 1)/2) / ((W - 1)/2);
expd = (Rcam - sqrt(Rcam^2 - x.^2)) / cam.pixel;      % circle about the axis
[pi_, pj] = meshgrid(2:6, 0:3);
pi_ = pi_(:)';  pj = pj(:)';
nB = numel(pi_);
sub = 1:8:W;                                          % columns used for the fit
Arows = {};  yv = {};
for k = 1:numel(tracks)
    c = (tracks{k}.outer + tracks{k}.inner) / 2;
    for i = 1:size(c, 1)
        ok = ~isnan(c(i, :));
        if nnz(ok) < 0.8 * W, continue; end
        cols = find(ok);
        q = polyfit(xn(ok), c(i, ok) - expd(ok), 1);
        r = c(i, sub) - expd(sub) - polyval(q, xn(sub));
        yy = (c(i, sub) - (H + 1)/2) / ((H - 1)/2);
        use = ~isnan(r);
        % basis, with each groove's own straight line projected out
        Bm = xn(sub(use))'.^pi_ .* yy(use)'.^pj;
        Z = [ones(nnz(use), 1), xn(sub(use))'];
        Bm = Bm - Z * (Z \ Bm);
        Arows{end+1} = Bm;           %#ok<AGROW>
        yv{end+1} = r(use)';         %#ok<AGROW>
    end
end
prof = [];
if numel(Arows) < 20, return; end
A = vertcat(Arows{:});  y = vertcat(yv{:});
a = A \ y;
for it = 1:3                                          % robust (Huber) refits
    e = y - A * a;
    s = 1.4826 * median(abs(e));
    w = min(1, 2 * s ./ max(abs(e), eps));
    a = (A .* sqrt(w)) \ (y .* sqrt(w));
end
[XN, YN] = meshgrid(xn, ((1:H) - (H + 1)/2) / ((H - 1)/2));
prof = zeros(H, W);
for b = 1:nB
    prof = prof + a(b) * XN.^pi_(b) .* YN.^pj(b);
end
for k = 1:numel(tracks)
    for f = {'outer', 'inner'}
        R = tracks{k}.(f{1});
        ok = ~isnan(R);
        [cc, ~] = meshgrid(1:W, 1:size(R, 1));
        rr = min(max(round(R(ok)), 1), H);
        R(ok) = R(ok) - prof(sub2ind([H W], rr, cc(ok)));
        tracks{k}.(f{1}) = R;
    end
end
end
