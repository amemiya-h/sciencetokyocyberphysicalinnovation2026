function fig = plot_groove(x, y, Z)
%PLOT_GROOVE  3-D view and top view of a groove surface patch.
%   fig = PLOT_GROOVE(x, y, Z), x and y grid vectors (um), Z height (um).

fig = figure('Color', 'w');

subplot(1, 2, 1);
surf(x, y, Z, Z, 'EdgeColor', 'none');
colormap(gca, gray(256));
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
zlabel('Height, z (\mum)');
title('Groove surface');
axis tight;
view(45, 30);
camlight;
lighting gouraud;

subplot(1, 2, 2);
imagesc(x, y, Z);
set(gca, 'YDir', 'normal');
axis image;
colormap(gca, gray(256));
colorbar;
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title('Height (top view)');
end
