function [z, isWall] = groove_profile(u, d, scene)
%GROOVE_PROFILE  Height of one V-groove at a distance from its centreline.
%   [z, isWall] = GROOVE_PROFILE(u, d, scene)
%   u      distance from the groove centreline (um), any array
%   d      groove depth (um), same size as u or broadcastable to it
%   scene  includedAngle (deg), bottomRadius and rimRadius (um)
%   z      height (um): 0 on the land, down to about -d at the centre
%   isWall true on the straight walls (not the rounded bottom or rim)

beta = 90 - scene.includedAngle/2;      % wall angle from horizontal (deg)
t = tand(beta);
rb = scene.bottomRadius;
re = scene.rimRadius;

zWall = -d + u*t;

% Bottom circle tangent to both walls
uB = rb * sind(beta);
zB = (-d + rb/cosd(beta)) - sqrt(max(rb^2 - u.^2, 0));

% Rim fillet tangent to the wall and to the land
uC = (re/cosd(beta) - re + d) / t;      % where the fillet meets the land
uR = uC - re*sind(beta);                % where the fillet meets the wall
zR = -re + sqrt(max(re^2 - (u - uC).^2, 0));

z = zWall;
inBottom = u < uB;
inRim = u >= uR & u < uC;
z(inBottom) = zB(inBottom);
z(inRim) = zR(inRim);
z(u >= uC) = 0;
z = min(z, 0);
isWall = ~inBottom & u < uR;
end
