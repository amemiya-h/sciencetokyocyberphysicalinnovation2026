function lut = reflectance_lut(group, cam, scene)
%REFLECTANCE_LUT  Camera signal vs surface orientation, for one light.
%   lut = REFLECTANCE_LUT(group, cam, scene) tabulates how much of the
%   light from one group (see light_sources) a surface patch sends into
%   the lens, as a function of the patch's unit normal (nx, ny).
%
%   Physics
%   - Specular: microfacet (Beckmann) reflection with rms slope
%     scene.roughness and Fresnel reflectance of index
%     scene.refractiveIndex, collected over the lens acceptance cone
%     (half-angle asin(cam.NA) about vertical).
%   - Diffuse: Lambertian, albedo scene.diffuseAlbedo.
%   - Double bounce: a 90-degree V-groove is a corner reflector in its
%     cross-section, so light hitting one wall bounces off the other and
%     returns towards where it came from. This is only collected when the
%     returned light falls inside the lens cone (coaxial lighting).
%     Stored separately as lut.doubleBounce (signal per unit wall area).
%
%   Signal units: 1 = a perfect mirror under the full illumination.
%
%   Output fields
%     nx, ny        grid of normal components
%     S             signal for each (ny, nx)
%     doubleBounce  signal from wall pixels via the double reflection
%     central       central light direction (for self-shadowing)

m = scene.roughness;
nIdx = scene.refractiveIndex;
alpha = asin(cam.NA);
accSolid = 2*pi*(1 - cos(alpha));

% Lens acceptance directions
V = cone_samples([0 0 1], alpha, 0.01);
dOmega = accSolid / size(V, 1);

% Distribution of half-vectors over all light/view pairs, Fresnel-weighted
binStep = m / 4;
L = group.dirs;
E = group.E;
nV = size(V, 1);
keys = zeros(size(L, 1) * nV, 2);
wts = zeros(size(L, 1) * nV, 1);
for k = 1:size(L, 1)
    H = L(k, :) + V;
    H = H ./ sqrt(sum(H.^2, 2));
    F = fresnel_reflectance(H * L(k, :)', nIdx);
    rows = (k - 1)*nV + (1:nV);
    keys(rows, :) = round(H(:, 1:2) / binStep);
    wts(rows) = E(k) * dOmega * F;
end
[uk, ~, j] = unique(keys, 'rows');
W = accumarray(j, wts);
hxy = uk * binStep;
hb = [hxy, sqrt(max(1 - sum(hxy.^2, 2), 0))];
hb = hb ./ sqrt(sum(hb.^2, 2));

% Table over surface normals
step = min(0.01, m/3);
lut.nx = -0.85:step:0.85;
lut.ny = lut.nx;
[NX, NY] = meshgrid(lut.nx, lut.ny);
NZ = sqrt(max(1 - NX.^2 - NY.^2, 0));
N = [NX(:), NY(:), NZ(:)];

spec = zeros(size(N, 1), 1);
chunk = 200;
for b = 1:chunk:size(hb, 1)
    bb = b:min(b + chunk - 1, size(hb, 1));
    c = N * hb(bb, :)';                                   % cos(normal, half)
    c(c <= 0) = NaN;
    tan2 = (1 - c.^2) ./ c.^2;
    D = exp(-tan2 / m^2) ./ (pi * m^2 * c.^4);
    D(isnan(D)) = 0;
    spec = spec + D * W(bb);
end
spec = spec ./ (4 * max(NZ(:), 1e-3));

diffuse = scene.diffuseAlbedo/pi * accSolid * (max(N * L', 0) * E);

S = spec + diffuse;
S(NZ(:) == 0 | N * group.central(:) <= 0) = 0;          % facing away
lut.S = reshape(S, size(NX));
lut.central = group.central;

% Double bounce in the V-groove (exact corner reflector only at 90 deg)
lut.doubleBounce = 0;
if abs(scene.includedAngle - 90) < 5
    beta = 90 - scene.includedAngle/2;
    nw = [sind(beta), 0, cosd(beta)];
    out = [L(:, 1), -L(:, 2), L(:, 3)];                  % returned direction
    state = rng;
    rng(1);                                               % fixed: deterministic
    jitter = 2*sqrt(2)*m * randn(400, 2);                % two rough bounces
    rng(state);
    captured = zeros(size(L, 1), 1);
    for k = 1:size(L, 1)
        tilt = out(k, 1:2) + jitter;                      % small-angle approx
        captured(k) = mean(sqrt(sum(tilt.^2, 2)) < sin(alpha));
    end
    cos1 = abs(L * nw');
    cos2 = cos(pi/2 - acos(cos1));
    [~, Rs1, Rp1] = fresnel_reflectance(cos1, nIdx);
    [~, Rs2, Rp2] = fresnel_reflectance(cos2, nIdx);
    Rdb = (Rs1.*Rs2 + Rp1.*Rp2) / 2;
    lut.doubleBounce = sum(E .* L(:, 3) .* Rdb .* captured);
end
end
