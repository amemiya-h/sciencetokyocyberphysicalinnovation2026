function cache_put(file, key, D, fmt)
%CACHE_PUT  Save struct D (plus cacheKey) to FILE atomically, in format FMT.
D.cacheKey = key; %#ok<STRNU>
tmp = [file '.tmp.mat'];
save(tmp, '-struct', 'D', fmt);
movefile(tmp, file, 'f');
end
