function [P, th, r] = unwarp_frame(I, cam, Rcam, alpha, prof)
%UNWARP_FRAME  Resample an image onto angle x radius about the rig axis.
%   [P, th, r] = UNWARP_FRAME(I, cam, Rcam, alpha, prof) returns the image
%   on a grid of angle th (columns, rad, 0 = image centre, increasing to
%   the right) and radius r (rows, um, decreasing downward like the image,
%   so the record's outer edge stays at the top). Silent grooves then run
%   exactly along the rows, and each column is perpendicular to them: the
%   direction the stylus is pushed. Grid steps: one pixel along both.
%   prof (optional, H x W, px) is the lens distortion from
%   correct_row_distortion: the image is sampled where a point really
%   appears, i.e. prof rows lower than the ideal camera puts it.

[H, W] = size(I);
p = cam.pixel;
th = ((1:W) - (W + 1)/2) * p / Rcam;
r = Rcam - ((1:H)' - (H + 1)/2) * p;
[TH, RR] = meshgrid(th, r);
xc = RR .* sin(TH);
yc = RR .* cos(TH) - Rcam;
X = xc * cos(alpha) + yc * sin(alpha);
dy = -xc * sin(alpha) + yc * cos(alpha);
cols = X / p + (W + 1)/2;
rows = -dy / p + (H + 1)/2;
if nargin >= 5 && ~isempty(prof)
    rr = min(max(round(rows), 1), H);
    cc = min(max(round(cols), 1), W);
    rows = rows + prof(sub2ind([H W], rr, cc));
end
P = interp2(I, cols, rows, 'linear', NaN);
end
