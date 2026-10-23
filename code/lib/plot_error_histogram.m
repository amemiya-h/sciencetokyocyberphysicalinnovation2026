function fig = plot_error_histogram(errors, labels)
%PLOT_ERROR_HISTOGRAM  Distributions of absolute error on shared bins.
%   fig = PLOT_ERROR_HISTOGRAM(errors, labels), cell arrays, errors in um.

allAbs = abs(vertcat(errors{:}));
edges = linspace(0, max(allAbs), 21);

fig = figure('Color', 'w');
hold on;
for k = 1:numel(errors)
    histogram(abs(errors{k}), edges, 'Normalization', 'probability');
end
hold off;
xlabel('Absolute centreline error (\mum)');
ylabel('Fraction of samples');
title('Distribution of absolute error');
legend(labels, 'Location', 'best');
grid on;
end
