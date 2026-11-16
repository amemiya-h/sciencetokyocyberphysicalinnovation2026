function [theta, r] = frame_to_polar(rows, cols, cam, Rcam, alpha)
%FRAME_TO_POLAR  Image pixel positions -> polar coordinates about the rig axis.
%   [theta, r] = FRAME_TO_POLAR(rows, cols, cam, Rcam, alpha)
%   rows, cols  pixel positions (1-based, sub-pixel allowed, same size)
%   cam         needs pixel (um) and imageSize [H W]
%   Rcam        distance of the image centre from the rig axis (um)
%   alpha       camera skew relative to the groove direction (rad)
%   theta       angle about the rig axis (rad), increasing to the right
%   r           radius (um)
%   The inverse of the camera geometry used in render_disc_frame.

H = cam.imageSize(1);
W = cam.imageSize(2);
X = (cols - (W + 1)/2) * cam.pixel;
dy = -(rows - (H + 1)/2) * cam.pixel;          % outward from image centre
xc = X .* cos(alpha) - dy .* sin(alpha);
yc = Rcam + X .* sin(alpha) + dy .* cos(alpha);
r = sqrt(xc.^2 + yc.^2);
theta = atan2(xc, yc);
end
