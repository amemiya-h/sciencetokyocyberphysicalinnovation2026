function root = project_root()
%PROJECT_ROOT  Absolute path of the repository root.
%   root = PROJECT_ROOT() returns the folder containing startup.m,
%   independent of the current working directory.

root = fileparts(fileparts(mfilename('fullpath')));
end
