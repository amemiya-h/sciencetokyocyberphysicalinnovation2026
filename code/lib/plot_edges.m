function fig = plot_edges(x, y, I, tr, trueLeft, trueRight, xCentre)
%PLOT_EDGES  Detected edges and centreline over the intensity image.
%   fig = PLOT_EDGES(x, y, I, tr, trueLeft, trueRight, xCentre)
%   tr is the struct from track_groove_edges; trueLeft/trueRight are the
%   geometric groove edges and xCentre the reconstructed centreline (um).

fig = figure('Color', 'w');
imagesc(x, y, I);
set(gca, 'YDir', 'normal');
axis image;
colormap(gca, gray(256));
clim([0 1]);
hold on;
plot(trueLeft, y, 'c-', 'LineWidth', 1.5);
plot(trueRight, y, 'c-', 'LineWidth', 1.5);
plot(tr.left, y, 'r.', 'MarkerSize', 5);
plot(tr.right, y, 'b.', 'MarkerSize', 5);
plot(xCentre, y, 'y-', 'LineWidth', 1.2);
hold off;
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title('Detected edges vs true groove boundaries');
legend('True left edge', 'True right edge', 'Detected left', ...
    'Detected right', 'Estimated centreline', 'Location', 'bestoutside');
end
