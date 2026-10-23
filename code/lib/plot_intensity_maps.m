function fig = plot_intensity_maps(x, y, maps, titles)
%PLOT_INTENSITY_MAPS  Side-by-side greyscale intensity images on [0 1].
%   fig = PLOT_INTENSITY_MAPS(x, y, maps, titles) where maps and titles
%   are cell arrays of equal length. x, y in um.

fig = figure('Color', 'w');
for k = 1:numel(maps)
    subplot(1, numel(maps), k);
    imagesc(x, y, maps{k});
    set(gca, 'YDir', 'normal');
    axis image;
    colormap(gca, gray(256));
    clim([0 1]);
    colorbar;
    xlabel('Across groove, x (\mum)');
    ylabel('Along groove, y (\mum)');
    title(titles{k});
end
sgtitle('Simulated reflected-light intensity');
end
