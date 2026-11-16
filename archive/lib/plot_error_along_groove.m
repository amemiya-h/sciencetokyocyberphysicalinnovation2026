function fig = plot_error_along_groove(y, errors, labels, lambda)
%PLOT_ERROR_ALONG_GROOVE  Centreline error vs position along the groove.
%   fig = PLOT_ERROR_ALONG_GROOVE(y, errors, labels, lambda)
%   errors and labels are cell arrays; y, lambda and errors in um.
%   For a sinusoidal groove, pass its wavelength as lambda to mark the
%   turning points (red dotted) and zero crossings (blue dotted); pass []
%   otherwise.

fig = figure('Color', 'w');
hold on;
for k = 1:numel(errors)
    plot(y, errors{k}, 'LineWidth', 1.2);
end
if ~isempty(lambda)
    for yt = lambda/4 : lambda/2 : max(y)
        xline(yt, 'r:', 'HandleVisibility', 'off');
    end
    for yz = 0 : lambda/2 : max(y)
        xline(yz, 'b:', 'HandleVisibility', 'off');
    end
end
yline(0, 'k--', 'HandleVisibility', 'off');
hold off;
xlabel('Along groove, y (\mum)');
ylabel('Centreline error (\mum)');
if isempty(lambda)
    title('Error along the groove');
else
    title('Error along the groove (red: turning points, blue: zero crossings)');
end
legend(labels, 'Location', 'best');
grid on;
end
