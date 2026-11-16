function profile = sliceProfile(frame, leftEdge, rightEdge)
%SLICEPROFILE  Average an image over a vertical slice with fractional edges.
%
%   profile = groove.scan.sliceProfile(frame, leftEdge, rightEdge)
%
%   Pixel k is taken to cover k-0.5 .. k+0.5. Pixels only partly inside the
%   slice count in proportion to the part that is inside, so the slice sits
%   exactly where asked instead of snapping to whole pixels. That matters:
%   a slice that is off along the groove samples the audio at the wrong time.

pixels  = floor(leftEdge + 0.5):floor(rightEdge + 0.5);
pixels  = pixels(pixels >= 1 & pixels <= size(frame, 2));
overlap = min(pixels + 0.5, rightEdge) - max(pixels - 0.5, leftEdge);
profile = frame(:, pixels) * (overlap(:) / sum(overlap));
end
