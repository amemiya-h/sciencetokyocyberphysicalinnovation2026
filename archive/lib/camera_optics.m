function P = camera_optics(S, Z, dx, cam)
%CAMERA_OPTICS  Lens blur, defocus and pixel integration.
%   P = CAMERA_OPTICS(S, Z, dx, cam) blurs the supersampled signal S by
%   the lens PSF (Gaussian approximation of the Airy disc, sigma =
%   0.21*wavelength/NA) and by defocus, which grows with depth below the
%   focal plane (focused on the land, z = 0); depth is handled in layers.
%   It averages cam.sub x cam.sub samples per pixel, then applies the
%   depth-independent blur of imperfect optics (cam.aberration) on the
%   pixel grid.
%
%   Inputs: S, Z on a square grid of spacing dx (um); Z in um.
%   Output: P on the pixel grid.

sigma0 = 0.21 * cam.wavelength / cam.NA;
tanA = tan(asin(cam.NA));
layerEdges = [Inf, -3, -8, -15, -25, -Inf];

B = zeros(size(S));
for k = 1:numel(layerEdges) - 1
    inLayer = Z <= layerEdges(k) & Z > layerEdges(k + 1);
    if ~any(inLayer(:))
        continue;
    end
    zMid = mean(Z(inLayer));
    sigma = hypot(sigma0, abs(zMid) * tanA / 2);    % defocus disc ~ 2 sigma
    B = B + gauss_blur(S .* inLayer, sigma / dx);
end

% Average sub x sub blocks into pixels
s = cam.sub;
[nr, nc] = size(B);
B = B(1:floor(nr/s)*s, 1:floor(nc/s)*s);
P = squeeze(mean(mean(reshape(B, s, nr/s, s, nc/s), 1), 3));
P = gauss_blur(P, cam.aberration / (dx * s));
end

function B = gauss_blur(A, sigma)
if sigma < 0.3
    B = A;
    return;
end
h = ceil(3 * sigma);
k = exp(-0.5 * ((-h:h) / sigma).^2);
k = k / sum(k);
B = conv2(k, k, A, 'same');
end
