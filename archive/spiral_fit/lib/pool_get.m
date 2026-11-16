function pool_get()
%POOL_GET  Start a thread-based parallel pool if none is running.
%   Thread workers share the client's memory, which matters here: the
%   frames are large and the PC's RAM is limited. In Octave parfor simply
%   runs serially.
if exist('OCTAVE_VERSION', 'builtin'), return; end
if isempty(gcp('nocreate'))
    try
        parpool('Threads');
    catch err
        fprintf('  could not start a thread pool (%s); trying processes\n', err.message);
        parpool('Processes', 4);
    end
end
end
