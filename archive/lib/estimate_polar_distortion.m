function [prof, slope] = estimate_polar_distortion(G, H, W)
%ESTIMATE_POLAR_DISTORTION  The optics' bend of the grooves, from unwarped images.
%   [prof, slope] = ESTIMATE_POLAR_DISTORTION(G, H, W) uses grooves read
%   from unwarped images (read_grooves_polar) where, without distortion,
%   a silent groove would be a straight row. Music differs from groove to
%   groove and image to image, so what all grooves share, after each one's
%   own straight line is removed, is the distortion: fitted as a smooth
%   surface sum a_ij x^i y^j (i = 2..6, j = 0..3; x, y image position
%   scaled to -1..1) and returned as prof (H x W, rows), ready for
%   unwarp_frame. slope is the median slope of the grooves (rows per
%   column); it should be ~0 when the camera skew is right.

xn = ((1:W) - (W + 1)/2) / ((W - 1)/2);
[pi_, pj] = meshgrid(2:6, 0:3);
pi_ = pi_(:)';  pj = pj(:)';
sub = 1:8:W;
Arows = {};  yv = {};  sl = [];
for k = 1:numel(G)
    c = double(G{k}.c);
    for i = 1:size(c, 1)
        ok = ~isnan(c(i, :));
        if nnz(ok) < 0.8 * W, continue; end
        q = polyfit(xn(ok), c(i, ok), 1);
        sl(end+1) = q(1) / ((W - 1)/2);   %#ok<AGROW>
        r = c(i, sub) - polyval(q, xn(sub));
        yy = (c(i, sub) - (H + 1)/2) / ((H - 1)/2);
        use = ~isnan(r);
        Bm = xn(sub(use))'.^pi_ .* yy(use)'.^pj;
        Z = [ones(nnz(use), 1), xn(sub(use))'];
        Bm = Bm - Z * (Z \ Bm);
        Arows{end+1} = Bm;          %#ok<AGROW>
        yv{end+1} = r(use)';        %#ok<AGROW>
    end
end
slope = median(sl);
prof = zeros(H, W);
if numel(Arows) < 20, return; end
A = vertcat(Arows{:});  y = vertcat(yv{:});
a = A \ y;
for it = 1:3
    e = y - A * a;
    s = 1.4826 * median(abs(e));
    w = min(1, 2 * s ./ max(abs(e), eps));
    a = (A .* sqrt(w)) \ (y .* sqrt(w));
end
[XN, YN] = meshgrid(xn, ((1:H) - (H + 1)/2) / ((H - 1)/2));
for b = 1:numel(a)
    prof = prof + a(b) * XN.^pi_(b) .* YN.^pj(b);
end
end
