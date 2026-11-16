%E04_PREPROCESS_DEMO  Show the groove-detection preprocessing on a few frames.
%   For frames 1 and 1152 of the 50x video: the cleaned image (lighting
%   flattened, scratches and specks closed along the groove direction) and
%   the dark runs found in it, numbered by counting from the clean middle,
%   drawn over the original frame. Dust blobs are shaded. Output:
%   <run>/preproc_k####.png.
run = '20261027_184833';
vf = fullfile(project_root(), 'data', 'keyence_recording', [run '.avi']);
dirR = fullfile(project_root(), 'results', 'runs', run);
A = load(fullfile(dirR, 'partA.mat')); M = A.model; S = A.settings;
vs = vsrc_open(vf);
Pp = 42.57;
for k = [1 1152]
    [G, vs] = vsrc_frame(vs, k, S.microscope.mirrored);
    e = disc_eval(M, [-4; 4; 0; 0], [0; 0; 0; 4], k * ones(4, 1));
    slope = -((e.psi(2) - e.psi(1)) / 8) / ((e.psi(4) - e.psi(3)) / 4);
    tic; [Gc, dark, blob] = groove_clean(G, Pp, slope, S); tc = toc;
    % dark runs per column -> centres (every 8th column for the plot)
    cols = 8:8:M.W; X = []; Y = []; V = [];
    for c = cols
        dc = dark(:, c) & ~blob(:, c);
        d = diff([false; dc; false]);
        rs = find(d == 1); re = find(d == -1) - 1;
        X = [X; c * ones(numel(rs), 1)]; Y = [Y; (rs + re) / 2]; %#ok<AGROW>
    end
    fig = figure('Visible', 'off', 'Position', [0 0 2 * M.W / 2.5, M.H / 2.5]);
    subplot(1, 2, 1); imagesc(Gc); colormap(gray); axis image off; title(sprintf('cleaned, frame %d (%.2f s)', k, tc));
    subplot(1, 2, 2); imagesc(G); colormap(gray); axis image off; hold on;
    [bx, by] = find(blob'); plot(bx(1:20:end), by(1:20:end), '.', 'Color', [0 0.6 1], 'MarkerSize', 2);
    plot(X, Y, '.', 'Color', [1 0.2 0.2], 'MarkerSize', 5);
    title('dark runs found (red), dust blobs (blue)');
    f = fullfile(dirR, sprintf('preproc_k%04d.png', k));
    print(fig, f, '-dpng', '-r110'); close(fig);
    fprintf('frame %d: cleaning %.2f s, %d runs in %d columns (%.1f per column)\n', k, tc, numel(X), numel(cols), numel(X) / numel(cols));
end
