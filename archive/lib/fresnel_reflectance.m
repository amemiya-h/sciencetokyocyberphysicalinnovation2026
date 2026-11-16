function [R, Rs, Rp] = fresnel_reflectance(cosI, n)
%FRESNEL_REFLECTANCE  Reflectance of a dielectric surface.
%   [R, Rs, Rp] = FRESNEL_REFLECTANCE(cosI, n): cosine of the angle of
%   incidence, refractive index n (from air). R is the unpolarised mean.

cosI = min(max(abs(cosI), 0), 1);
sinT = sqrt(1 - cosI.^2) / n;
cosT = sqrt(max(1 - sinT.^2, 0));
Rs = ((cosI - n*cosT) ./ (cosI + n*cosT)).^2;
Rp = ((n*cosI - cosT) ./ (n*cosI + cosT)).^2;
R = (Rs + Rp) / 2;
end
