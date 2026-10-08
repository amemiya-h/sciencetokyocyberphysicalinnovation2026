function paths = save_figure(fig, expId, name)
%SAVE_FIGURE  Save a figure to results/figures/ as PNG and PDF.
%   paths = SAVE_FIGURE(fig, expId, name) writes
%   results/figures/<expId>_<name>.png and .pdf and returns both paths.
%
%   Inputs
%     fig    figure handle
%     expId  experiment ID, e.g. 'E003'
%     name   short descriptive name, e.g. 'parameter_estimates'

outDir = fullfile(project_root(), 'results', 'figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

base = fullfile(outDir, sprintf('%s_%s', expId, name));
paths = {[base '.png'], [base '.pdf']};

exportgraphics(fig, paths{1}, 'Resolution', 200);
exportgraphics(fig, paths{2}, 'ContentType', 'vector');
end
