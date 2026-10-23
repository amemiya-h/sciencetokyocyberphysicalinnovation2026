function simulate_scan(sig, fs, tOffset, clipLength, scene, cam, light, outDir, frameRows)
%SIMULATE_SCAN  Forward model: audio -> groove -> camera frames on disk.
%   SIMULATE_SCAN(sig, fs, tOffset, clipLength, scene, cam, light,
%                 outDir, frameRows)
%   cuts the audio into a groove (with the neighbouring turns), renders
%   what the camera sees, and writes the frames for the retrieval path.
%
%   Frames are rendered with parfor, so with the Parallel Computing
%   Toolbox they run on all cores (without it, one at a time). Frames
%   already in outDir are kept, so an interrupted run can be restarted
%   and continues where it stopped; delete outDir to start afresh. Each
%   frame's noise is seeded by its number, so results are repeatable.
%
%   Inputs
%     sig, fs     audio (n x 1 or n x 2) and sample rate (Hz). It must
%                 start at least scene.nNeighbours revolutions before the
%                 clip and end that long after it, so the neighbouring
%                 turns can be cut from the same recording.
%     tOffset     time in sig where the clip starts (s)
%     clipLength  length of the clip to scan (s)
%     scene       see default_scene
%     cam         see camera_preset
%     light       see light_sources
%     outDir      output folder, created if needed
%     frameRows   pixel rows per frame along the groove
%
%   Files written to outDir
%     frame_00001.png, ...  sensor values rescaled to 16 bits
%     meta.mat              what the instrument knows: pixel grid x, y,
%                           pixel size dy, scene, cam, light, frameRows,
%                           nFrames, grooveSpeed (m/s), adcMax, exposure
%     truth.mat             true lateral (xc) and vertical (vert) motion of
%                           the scanned groove per pixel row; evaluation only

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

speed = 2*pi*scene.radius * scene.rpm/60 * 1e6;     % um/s
tRev = 60 / scene.rpm;
p = cam.pixel;
if ~strcmp(light.type, 'coaxial')
    % Under low side/ring light the edges show up only as thin highlights
    % on the rounded rims (radius scene.rimRadius), which need a fine grid
    cam.sub = max(cam.sub, ceil(p / min(0.15, scene.rimRadius/6)));
end
sub = cam.sub;
dys = p / sub;
subX = 8;               % extra anti-aliasing across the groove

% Groove motion at the audio rate, for the whole signal
[lat, vert, info] = audio_to_groove(sig, fs, scene);
fprintf('  peak lateral velocity %.1f cm/s, peak vertical %.1f um\n', ...
    info.peakVelocity, info.peakVertical);
grooveAt = @(v, t) groove_motion_at(v, fs, t);

% Pixel grid, padded so blur at the borders is right
nRows = floor(clipLength * speed / p);
halfPix = floor(scene.halfWidth / p);
x = (-halfPix:halfPix) * p;
sigmaMax = hypot(hypot(0.21*cam.wavelength/cam.NA, cam.aberration), ...
                 35 * tan(asin(cam.NA)) / 2);
padPix = ceil(3 * sigmaMax / p) + 2;
xPix = (-halfPix - padPix : halfPix + padPix) * p;
off = ((1:sub)' - (sub + 1)/2) * dys;
xs = reshape(off + xPix, 1, []);

% Lights
groups = light_sources(light, cam);
for g = 1:numel(groups)
    luts(g) = reflectance_lut(groups(g), cam, scene);         %#ok<AGROW>
end
% Brightness of the flat land: the reference for stray light (cam.glare)
landLevel = 0;
for g = 1:numel(groups)
    landLevel = landLevel + interp2(luts(g).nx, luts(g).ny, luts(g).S, 0, 0);
end

% Everything a frame needs, so frames can be rendered independently
c.offsets = -scene.nNeighbours : scene.nNeighbours;   % +1 = next turn outwards
c.lat = lat;  c.vert = vert;  c.fs = fs;
c.tOffset = tOffset;  c.tRev = tRev;  c.speed = speed;
c.p = p;  c.sub = sub;  c.subX = subX;  c.dys = dys;  c.off = off;  c.xs = xs;
c.padPix = padPix;  c.frameRows = frameRows;  c.nRows = nRows;
c.scene = scene;  c.cam = cam;  c.groups = groups;  c.luts = luts;
c.landLevel = landLevel;

nFrames = ceil(nRows / frameRows);
file1 = fullfile(outDir, 'frame_00001.png');

% The first frame sets the exposure for the whole scan
P = frame_signal(1, c);
v = sort(P(:));
exposure = 0.8 * cam.fullWell / max(v(ceil(0.995*numel(v))), eps);
c.exposure = exposure;
if ~exist(file1, 'file')
    write_frame(P, 1, c, file1);
end

fprintf('  rendering %d frames\n', nFrames);
parfor k = 2:nFrames
    file = fullfile(outDir, sprintf('frame_%05d.png', k));
    if exist(file, 'file')
        continue;                          % done in an earlier run
    end
    write_frame(frame_signal(k, c), k, c, file);
    if mod(k, 100) == 0
        fprintf('  wrote frame %d\n', k);
    end
end

meta.x = x;
meta.y = (0:nRows-1)' * p;
meta.dy = p;
meta.scene = scene;
meta.cam = cam;
meta.light = light;
meta.frameRows = frameRows;
meta.nFrames = nFrames;
meta.grooveSpeed = speed / 1e6;
meta.adcMax = 65535;
meta.exposure = exposure;
save(fullfile(outDir, 'meta.mat'), '-struct', 'meta');

tRow = tOffset + meta.y / speed;
xc = grooveAt(lat, tRow);
vert = grooveAt(vert, tRow);
save(fullfile(outDir, 'truth.mat'), 'xc', 'vert');
end

function P = frame_signal(k, c)
% Light reaching each pixel of frame k (before the sensor)
rowsPix = (k - 1)*c.frameRows + 1 : min(k*c.frameRows, c.nRows);
ext = rowsPix(1) - c.padPix : rowsPix(end) + c.padPix;
ys = reshape(c.off + (ext - 1)*c.p, [], 1);
t = c.tOffset + ys / c.speed;

centres = zeros(numel(ys), numel(c.offsets));
depths = centres;
for g = 1:numel(c.offsets)
    tg = t - c.offsets(g)*c.tRev;          % the outer turn was cut earlier
    centres(:, g) = c.offsets(g)*c.scene.pitch + groove_motion_at(c.lat, c.fs, tg);
    depths(:, g) = c.scene.depth - groove_motion_at(c.vert, c.fs, tg);
end

% Render at subX x finer spacing across the groove, where the sharp
% land/wall edges are, then average back (anti-aliasing)
xf = reshape(c.xs + ((1:c.subX)' - (c.subX + 1)/2) * c.dys/c.subX, 1, []);
[Zf, wall] = groove_surface(xf, centres, depths, c.scene);
dust = dust_mask(xf, ys, c.scene.dust, k);
Sf = scene_radiance(Zf, wall, dust, c.dys/c.subX, c.dys, c.groups, c.luts, ...
                    c.cam, c.scene);
S = squeeze(mean(reshape(Sf, size(Sf, 1), c.subX, []), 2));
Z = squeeze(mean(reshape(Zf, size(Zf, 1), c.subX, []), 2));
P = camera_optics(S, Z, c.dys, c.cam);
P = P(c.padPix + 1 : end - c.padPix, c.padPix + 1 : end - c.padPix);
P = P + c.cam.glare * c.landLevel;
end

function write_frame(P, k, c, file)
% Sensor noise (seeded by the frame number) and save
rng(k);
DN = camera_sensor(P, c.cam, c.exposure);
imwrite(uint16(round(DN * 65535 / (2^c.cam.bits - 1))), file);
end
