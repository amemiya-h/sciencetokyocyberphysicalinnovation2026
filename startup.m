% STARTUP  Add project code to the MATLAB path.
% MATLAB runs this automatically when started in the repository root.
% Run it manually otherwise.

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'code')));

runsDir = fullfile(root, 'results', 'runs');
if ~exist(runsDir, 'dir')
    mkdir(runsDir);
end

fprintf('Project path set: %s\n', root);
clear root runsDir
