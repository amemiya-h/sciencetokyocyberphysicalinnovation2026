function fig = plot_edge_profiles(x, y, I, tr, trueLeft, trueRight, ...
                                  yPositions, labels, profileSmooth)
%PLOT_EDGE_PROFILES  Smoothed intensity across the groove at chosen rows,
%   with true (cyan) and detected (red/blue) edges marked.
%   fig = PLOT_EDGE_PROFILES(x, y, I, tr, trueLeft, trueRight,
%                            yPositions, labels, profileSmooth)
%   yPositions in um, labels a cell array of the same length.

fig = figure('Color', 'w');
n = numel(yPositions);
for k = 1:n
    [~, row] = min(abs(y - yPositions(k)));
    profile = smoothdata(I(row, :), 'gaussian', profileSmooth);

    subplot(n, 1, k);
    plot(x, profile, 'k-', 'LineWidth', 1.2);
    hold on;
    xline(trueLeft(row), 'c--', 'True left');
    xline(trueRight(row), 'c--', 'True right');
    if isfinite(tr.left(row))
        xline(tr.left(row), 'r-', 'Detected left');
    end
    if isfinite(tr.right(row))
        xline(tr.right(row), 'b-', 'Detected right');
    end
    hold off;
    ylabel('Intensity');
    title(sprintf('%s: y = %.1f \\mum', labels{k}, y(row)));
    grid on;
end
xlabel('Across groove, x (\mum)');
end
