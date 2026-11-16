function S = settings_load(over)
%SETTINGS_LOAD  Read code/settings.json, optionally overriding fields.
%   S = SETTINGS_LOAD() returns the settings struct.
%   S = SETTINGS_LOAD(over) merges the struct OVER into it (recursively),
%   e.g. over.microscope.magnification = 30.
S = jsondecode(fileread(fullfile(project_root(), 'code', 'settings.json')));
if nargin > 0 && ~isempty(over)
    S = merge(S, over);
end
end

function A = merge(A, B)
f = fieldnames(B);
for i = 1:numel(f)
    if isstruct(B.(f{i})) && isfield(A, f{i}) && isstruct(A.(f{i}))
        A.(f{i}) = merge(A.(f{i}), B.(f{i}));
    else
        A.(f{i}) = B.(f{i});
    end
end
end
