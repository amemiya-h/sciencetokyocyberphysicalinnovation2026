function [ok, D] = cache_get(file, key)
%CACHE_GET  Load a cached result if it exists and was made with the same key.
%   [ok, D] = CACHE_GET(file, key): ok is true when FILE exists and its
%   stored variable cacheKey equals KEY (a struct of the inputs that matter).
ok = false; D = [];
if ~exist(file, 'file'), return; end
try
    D = load(file);
catch err
    fprintf('  cache %s unreadable (%s), recomputing\n', file, err.message);
    return;
end
if isfield(D, 'cacheKey') && isequaln(D.cacheKey, key)
    ok = true;
else
    fprintf('  cache %s was made with other settings, recomputing\n', file);
end
end
