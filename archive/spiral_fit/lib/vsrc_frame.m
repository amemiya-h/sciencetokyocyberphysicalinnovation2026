function [G, vs] = vsrc_frame(vs, k, mirrored, thumbRef, ds)
%VSRC_FRAME  Read frame k (grey, full resolution) by seeking.
%   If thumbRef (the scan's 1/(4 ds) thumbnail of frame k) is given, the
%   frame read is checked against it; if the seek landed on another frame,
%   the video is decoded from the start up to frame k instead.
vs = vsrc_seek(vs, k);
[fr, ~, vs] = vsrc_read(vs);
G = gray_frame(fr, mirrored);
if nargin >= 4 && ~isempty(thumbRef)
    T = block_down(block_down(G, ds), 4);
    T = T(1:size(thumbRef, 1), 1:size(thumbRef, 2));
    err = mean(abs(T(:) - single(thumbRef(:))));
    if err > 2
        fprintf('  seek to frame %d missed (thumbnail mismatch %.1f), decoding from start\n', k, err);
        vs = vsrc_seek(vs, 1);
        for i = 1:k
            [fr, ~, vs] = vsrc_read(vs);
        end
        G = gray_frame(fr, mirrored);
    end
end
end
