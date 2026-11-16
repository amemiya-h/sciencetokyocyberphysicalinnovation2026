function S = scene_radiance(Z, wall, dust, dx, dy, groups, luts, cam, scene)
%SCENE_RADIANCE  Light sent into the lens by each point of the surface.
%   S = SCENE_RADIANCE(Z, wall, dust, dx, dy, groups, luts, cam, scene)
%
%   Inputs
%     Z, wall   height map and wall mask from groove_surface (um)
%     dust      logical dust mask from dust_mask
%     dx, dy    grid spacing across / along the groove (um)
%     groups    lights from light_sources
%     luts      one reflectance_lut per light
%     cam, scene  camera and scene parameters
%
%   Output
%     S   signal per grid point before the camera optics
%         (1 = a perfect mirror under the full illumination)

N = surface_normals(Z, dx, dy);
S = zeros(size(Z));
for g = 1:numel(groups)
    Sg = interp2(luts(g).nx, luts(g).ny, luts(g).S, N(:, :, 1), N(:, :, 2), ...
                 'linear', 0);
    Sg = Sg .* cast_shadow(Z, dx, groups(g).central);
    S = S + Sg + wall * luts(g).doubleBounce;
end

% Dust: a matte particle lying on the surface, seen from above
accSolid = 2*pi*(1 - cos(asin(cam.NA)));
S(dust) = scene.dust.albedo/pi * accSolid;
end
