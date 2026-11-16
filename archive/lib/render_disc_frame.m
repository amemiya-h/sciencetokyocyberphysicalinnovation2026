function P = render_disc_frame(gm, pose, cam, scene, groups, luts, landLevel)
%RENDER_DISC_FRAME  One microscope image of a record, in true disc geometry.
%   P = RENDER_DISC_FRAME(gm, pose, cam, scene, groups, luts, landLevel)
%   renders a full camera image (before the sensor) looking straight down
%   at the record. The image's long side runs along the grooves (left to
%   right = playing order) and its short side runs across them (top of
%   the image = outer edge of the record). All turns of the spiral inside
%   the field are drawn, with their true curvature.
%
%   Inputs
%     gm     spiral groove from disc_groove_model
%     pose   where the camera looks:
%              phi    rotation of the record on the rig (rad); the camera
%                     sees the groove passing angle phi
%              Rcam   distance of the image centre from the rig's axis (um)
%              ecc    [ex ey] offset of the groove spiral's centre from the
%                     rig's axis, in record coordinates (um)
%              align  rotation of the camera relative to the groove
%                     direction (rad), e.g. a slightly skewed mount
%     cam    camera_preset (pixel, imageSize, optics, sub)
%     scene  default_scene
%     groups, luts, landLevel   lights, reflectance tables and land
%            brightness (see simulate_scan)
%
%   Output
%     P      imageSize(1) x imageSize(2) signal per pixel; pass it to
%            camera_sensor to get digital numbers
%
%   Rendering works on strips of 128 image columns. Each strip uses a grid
%   cam.sub times finer than the pixels along the groove and 8x finer
%   again across it (where the sharp groove edges are), then blurs and
%   averages back to pixels as camera_optics does.

H = cam.imageSize(1);
W = cam.imageSize(2);
p = cam.pixel;
sub = cam.sub;
subX = 8;
dys = p / sub;                 % along the groove
dxf = dys / subX;              % across the groove (fine)
sigmaMax = hypot(hypot(0.21*cam.wavelength/cam.NA, cam.aberration), ...
                 35 * tan(asin(cam.NA)) / 2);
padPix = ceil(3 * sigmaMax / p) + 2;
hw = scene.depth * tand(scene.includedAngle/2);
margin = hw + scene.peakLateral + 20;

% Across the grooves: q increases down the image (towards the centre)
iPix = -padPix : H - 1 + padPix;
offQ = ((1:sub*subX) - (sub*subX + 1)/2) * dxf;
q = reshape(offQ' + (iPix - (H - 1)/2) * p, 1, []);

Pr = zeros(W, H);              % rendered transposed: rows along the groove
strip = 128;
Rat = @(t) interp1(gm.Rrest, min(max(1 + t*gm.fs, 1), numel(gm.Rrest)), 'linear');
for j0 = 0 : strip : W - 1
    j1 = min(j0 + strip, W) - 1;
    jPix = j0 - padPix : j1 + padPix;
    offA = ((1:sub)' - (sub + 1)/2) * dys;
    A = reshape(offA + (jPix - (W - 1)/2) * p, [], 1);

    % Camera -> rig -> record coordinates
    dy = -q;                                       % outward from image centre
    xc = A .* cos(pose.align) - dy .* sin(pose.align);
    yc = pose.Rcam + A .* sin(pose.align) + dy .* cos(pose.align);
    xm = xc .* cos(pose.phi) + yc .* sin(pose.phi);
    ym = -xc .* sin(pose.phi) + yc .* cos(pose.phi);
    xe = xm - pose.ecc(1);
    ye = ym - pose.ecc(2);
    r = sqrt(xe.^2 + ye.^2);
    th = atan2(xe, ye);
    thc = th(round(end/2), round(end/2));
    th = thc + mod(th - thc + pi, 2*pi) - pi;      % unwrap around the centre

    % Turns of the spiral that can appear in this strip
    tOf = @(m) (thc/(2*pi) + m) * gm.T;
    mAll = ceil(-thc/(2*pi)) : floor(numel(gm.Rrest)/gm.fs/gm.T - thc/(2*pi));
    Rm = Rat(tOf(mAll));
    rLo = min(r, [], 1);
    rHi = max(r, [], 1);
    mUse = mAll(Rm > min(rLo) - margin & Rm < max(rHi) + margin);

    Z = zeros(size(r));
    wall = false(size(r));
    for m = mUse
        Rc = Rat(tOf(m));
        J = find(rHi > Rc - margin & rLo < Rc + margin);
        if isempty(J), continue; end
        t = (th(:, J)/(2*pi) + m) * gm.T;
        centre = Rat(t) + groove_motion_at(gm.lat, gm.fs, t);
        depth = scene.depth - groove_motion_at(gm.vert, gm.fs, t);
        [z, w] = groove_profile(abs(r(:, J) - centre), depth, scene);
        Zj = Z(:, J);  Wj = wall(:, J);
        deeper = z < Zj;
        Zj(deeper) = z(deeper);  Wj(deeper) = w(deeper);
        Z(:, J) = Zj;  wall(:, J) = Wj;
    end

    defects = disc_defects_mask(xe, ye, scene);
    Sf = scene_radiance(Z, wall, defects, dxf, dys, groups, luts, cam, scene);
    S = squeeze(mean(reshape(Sf, size(Sf, 1), subX, []), 2));
    Zb = squeeze(mean(reshape(Z, size(Z, 1), subX, []), 2));
    Pj = camera_optics(S, Zb, dys, cam);
    Pr(j0 + 1 : j1 + 1, :) = Pj(padPix + 1 : end - padPix, padPix + 1 : end - padPix);
end

P = Pr' + cam.glare * landLevel;
end
