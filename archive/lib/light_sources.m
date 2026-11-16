function groups = light_sources(light, cam)
%LIGHT_SOURCES  Directions and strengths of the illumination.
%   groups = LIGHT_SOURCES(light, cam) returns one struct per physical
%   light (so each can cast its own shadows), with fields
%     dirs     k x 3 unit vectors from the record towards the light
%     E        k x 1 irradiance of each sample, normal to its direction
%     central  1 x 3 central direction
%   Irradiances are scaled so the total on a horizontal surface is 1.
%
%   light.type
%     'coaxial'  through the lens (beamsplitter); fills the lens aperture,
%                i.e. a cone of half-angle asin(cam.NA) about vertical
%     'side'     two small lights at light.angle from vertical (deg),
%                on either side of the groove (azimuth 0 and 180 deg)
%     'ring'     light.n small lights in a ring at light.angle
%   light.size   angular radius of each small light (deg), e.g. 2

switch light.type
    case 'coaxial'
        groups = make_group([0 0 1], asin(cam.NA));
    case 'side'
        groups = [make_group(dir_at(light.angle, 0), deg2rad(light.size)), ...
                  make_group(dir_at(light.angle, 180), deg2rad(light.size))];
    case 'ring'
        az = (0:light.n-1) * 360/light.n;
        groups = make_group(dir_at(light.angle, az(1)), deg2rad(light.size));
        for k = 2:light.n
            groups(k) = make_group(dir_at(light.angle, az(k)), deg2rad(light.size));
        end
    otherwise
        error('light_sources:type', 'Unknown light type "%s".', light.type);
end

% Normalise: total irradiance on a horizontal surface = 1
total = 0;
for g = 1:numel(groups)
    total = total + sum(groups(g).E .* groups(g).dirs(:, 3));
end
for g = 1:numel(groups)
    groups(g).E = groups(g).E / total;
end
end

function d = dir_at(incidence, azimuth)
d = [sind(incidence)*cosd(azimuth), sind(incidence)*sind(azimuth), cosd(incidence)];
end

function g = make_group(central, radius)
g.dirs = cone_samples(central, radius, 0.01);
g.E = ones(size(g.dirs, 1), 1) / size(g.dirs, 1);
g.central = central;
end
