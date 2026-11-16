function X = disc_from_image(M, k, x, y)
%DISC_FROM_IMAGE  Disc coordinates (um, 2 x n) of image points in frame k.
%   X = Rot(-theta_k) * (p*[x; y + d(x,y)] - p*c_k)   (method A2)
x = x(:)'; y = y(:)';
D = M.p * [x - M.c(k, 1); y + disc_distortion(M, x, y) - M.c(k, 2)];
t = M.theta(k);
X = [cos(t), sin(t); -sin(t), cos(t)] * D;
end
