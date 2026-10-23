function st = image_stats(I, x, xc, scene)
%IMAGE_STATS  Brightness of land, rim and wall, and noise, in one frame.
%   st = IMAGE_STATS(I, x, xc, scene)
%   I   frame scaled to [0,1] (read_groove_frame)
%   x   pixel positions across the groove (um)
%   xc  true centre of each row of I (um)
%   Output fields (fractions of full scale): land, rim, wall, noise.
%   Land is between this groove and its neighbours, the rim is the band
%   around the groove edges, and the wall is the middle of each wall.

halfW = scene.depth * tand(scene.includedAngle/2);
d = abs(x - xc);
land = d > halfW + 10 & d < scene.pitch - halfW - 10;
rim = d > halfW - 3 & d < halfW + 3;
wall = d > 0.3*halfW & d < 0.7*halfW;

st.land = median(I(land));
st.wall = median(I(wall));
rimMax = I;
rimMax(~rim) = -Inf;
st.rim = median(max(rimMax, [], 2));
dI = diff(I, 1, 1) / sqrt(2);
landPair = land(1:end-1, :) & land(2:end, :);
st.noise = std(dI(landPair));
end
