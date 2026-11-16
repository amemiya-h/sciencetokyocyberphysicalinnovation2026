function G = gray_frame(fr, mirrored)
%GRAY_FRAME  Convert a video frame to single grey levels (0..255).
if size(fr, 3) == 3
    G = 0.299 * single(fr(:, :, 1)) + 0.587 * single(fr(:, :, 2)) + 0.114 * single(fr(:, :, 3));
else
    G = single(fr);
end
if mirrored
    G = fliplr(G);
end
end
