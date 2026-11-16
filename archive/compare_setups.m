%% Compare candidate cameras and lighting before buying anything
% Runs the forward model and the retrieval for every combination of
% camera preset and lighting on the same short music clip, and tabulates
% how bright the land, groove rims and walls come out, the noise, and how
% well the audio is recovered. Each run is stored under data/setups/.
%
% The presets in camera_preset.m are typical values, not datasheets.
% Replace them with the real numbers of hardware you are considering.

clear; close all; clc;

presets = {'telecentric2x', 'usbMicroscope', 'phoneMacro', 'microscope10x'};

lights = {struct('type', 'coaxial'), ...
          struct('type', 'side', 'angle', 45, 'size', 2), ...
          struct('type', 'ring', 'angle', 30, 'size', 2, 'n', 8)};
lightNames = {'coaxial', 'side45', 'ring30'};

audioFile = fullfile(project_root(), 'data', 'brahms_hungarian_dance_5.ogg');
clipStart = 10;      % s
clipLength = 0.05;   % s; short, to keep the sweep quick
frameRows = 250;

scene = default_scene();
trackOpts = struct('widthTolerance', 0.5, 'trackingWindow', 8, 'startCentre', 0);
audioOpts = struct('band', [20 20e3], 'fsOut', 48e3);

margin = scene.nNeighbours * 60/scene.rpm + 0.05;
[sig, fs] = load_clip(audioFile, clipStart - margin, clipLength + 2*margin);

%% Run every combination

rows = {};
examples = {};
for i = 1:numel(presets)
    cam = camera_preset(presets{i});
    for j = 1:numel(lights)
        name = sprintf('%s_%s', presets{i}, lightNames{j});
        fprintf('\n=== %s ===\n', name);
        dataDir = fullfile(project_root(), 'data', 'setups', name);

        simulate_scan(sig, fs, margin, clipLength, scene, cam, lights{j}, ...
                      dataDir, frameRows);
        r = retrieve_audio(dataDir, trackOpts, audioOpts);

        [I, fr] = read_groove_frame(dataDir, r.meta, 1);
        st = image_stats(I, r.meta.x, r.truth.xc(fr), scene);
        examples{end+1} = {name, r.meta.x, r.meta.y(fr), I};     %#ok<SAGROW>

        rows(end+1, :) = {presets{i}, lightNames{j}, st.land, st.rim, ...
            st.wall, st.noise, 100*r.coverage, r.rmseDetected, r.snr}; %#ok<SAGROW>
        fprintf('coverage %.1f%%, RMSE %.3f um, SNR %.1f dB\n', ...
            100*r.coverage, r.rmseDetected, r.snr);
    end
end

results = cell2table(rows, 'VariableNames', {'Camera', 'Light', 'Land', ...
    'Rim', 'Wall', 'Noise', 'Coverage_pct', 'RMSE_um', 'SNR_dB'});
disp(results);

runsDir = fullfile(project_root(), 'results', 'runs');
if ~exist(runsDir, 'dir'), mkdir(runsDir); end
writetable(results, fullfile(runsDir, 'setup_comparison.csv'));

%% Figure: what each setup sees (first 300 um of the first frame)

fig = figure('Color', 'w', 'Position', [100 100 1400 900]);
for k = 1:numel(examples)
    [name, x, y, I] = examples{k}{:};
    show = y - y(1) <= 300;
    subplot(numel(presets), numel(lights), k);
    imagesc(x, y(show), I(show, :));
    set(gca, 'YDir', 'normal');
    axis image;
    colormap(gca, gray(256));
    title(strrep(name, '_', ' '));
end
save_figure(fig, 'setups', 'simulated_frames');
