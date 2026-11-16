function D = block_down(G, f)
%BLOCK_DOWN  Downsample an image by averaging f x f blocks.
if f == 1, D = G; return; end
[h, w] = size(G);
h2 = floor(h / f); w2 = floor(w / f);
G = G(1:h2*f, 1:w2*f);
D = reshape(sum(reshape(G, f, h2, f * w2), 1), h2, f, w2);
D = reshape(sum(D, 2), h2, w2) / f^2;
end
