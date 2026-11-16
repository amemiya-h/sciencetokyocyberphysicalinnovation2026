function [x, y] = disc_to_image(M, k, X)
%DISC_TO_IMAGE  Image position in frame k of disc points X (um, 2 x n).
t = M.theta(k);
D = [cos(t), -sin(t); sin(t), cos(t)] * X / M.p;
x = M.c(k, 1) + D(1, :);
y0 = M.c(k, 2) + D(2, :);
y = y0;
for it = 1:4
    y = y0 - disc_distortion(M, x, y);
end
end
