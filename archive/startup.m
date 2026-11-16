% STARTUP  Add project code to the MATLAB path.
% MATLAB runs this automatically when started in the repository root.
% Run it manually otherwise.

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'code')));
% the old implementation is kept for reference only: keep it off the path
% so its functions cannot shadow the new ones
archive = fullfile(root, 'code', 'archive');
if exist(archive, 'dir'), rmpath(genpath(archive)); end

runsDir = fullfile(root, 'results', 'runs');
if ~exist(runsDir, 'dir')
    mkdir(runsDir);
end

fprintf('Project path set: %s\n', root);
clear root runsDir archive
