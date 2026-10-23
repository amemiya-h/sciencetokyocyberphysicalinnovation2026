%% Simulated microscope views of a record playing stereo music
% Renders a patch of record with many neighbouring turns of the groove,
% cut from a public-domain stereo recording, as seen under a 5x
% reflected-light microscope with head-on (coaxial) lighting:
%   1. 'phoneEyepiece5x' - like a phone photo through the eyepiece (blur
%      and glare matched to a real photo)
%   2. 'microscope5x'    - an eyepiece camera at the image plane
% Each view is also a dataset under data/ that retrieve_centreline.m can
% read (it tracks the groove in the middle of the patch).
% Lengths in micrometres (um) unless stated.
%
% Music: Brahms, Hungarian Dance No. 5, The U.S. Army Strings. Public
% domain; see data/brahms_hungarian_dance_5_LICENSE.txt.

clear; close all; clc;

audioFile = fullfile(project_root(), 'data', 'brahms_hungarian_dance_5.ogg');
clipStart = 22;      % s; the middle turn of the patch plays from here

views = {
    % preset            field across x along (um)   field stop (um)
    'phoneEyepiece5x',  [2800 1900],                3000
    'microscope5x',     [1170  660],                []
};

light.type = 'coaxial';
look.tint = [222 178 106] / 255;     % lamp colour measured from a photo
look.vignetting = 0.35;

for v = 1:size(views, 1)
    cam = camera_preset(views{v, 1});
    field = views{v, 2};

    scene = default_scene();
    scene.pitch = 100;        % grooves fill ~half the spacing in the real photo
    scene.peakLateral = 15;   % keeps >= 20 um of land between turns at this
                              % pitch (lathes vary the pitch to ensure this)
    scene.nNeighbours = ceil(field(1) / 2 / scene.pitch);
    scene.halfWidth = field(1) / 2;

    speed = 2*pi*scene.radius * scene.rpm/60 * 1e6;     % um/s
    clipLength = field(2) / speed;                      % s along the groove
    margin = scene.nNeighbours * 60/scene.rpm + 0.05;
    [sig, fs] = load_clip(audioFile, clipStart - margin, clipLength + 2*margin);

    outDir = fullfile(project_root(), 'data', ['view_' views{v, 1}]);
    fprintf('\n=== %s: %d turns, %.1f ms of each ===\n', views{v, 1}, ...
        2*scene.nNeighbours + 1, 1e3*clipLength);
    tic;
    simulate_scan(sig, fs, margin, clipLength, scene, cam, light, outDir, 250);
    fprintf('Rendered in %.0f s\n', toc);

    % Put the frames back together into one picture
    meta = load(fullfile(outDir, 'meta.mat'));
    I = [];
    for k = 1:meta.nFrames
        I = [I; read_groove_frame(outDir, meta, k)];            %#ok<AGROW>
    end

    look.fieldStop = views{v, 3};
    rgb = eyepiece_look(I, meta.x, meta.y(1:size(I, 1)), look);

    figDir = fullfile(project_root(), 'results', 'figures');
    if ~exist(figDir, 'dir'), mkdir(figDir); end
    imwrite(rgb, fullfile(figDir, sprintf('view_%s.png', views{v, 1})));
    imwrite(uint16(round(I' * 65535)), ...
        fullfile(figDir, sprintf('view_%s_mono.png', views{v, 1})));

    figure('Color', 'w');
    image(meta.y(1:size(I, 1)), meta.x, rgb);
    axis image;
    xlabel('Along the groove (\mum)');
    ylabel('Across the grooves (\mum)');
    title(sprintf('Simulated: %s', views{v, 1}));
end
