function R = run_open(name, S)
%RUN_OPEN  Create results/runs/<name>/ with a cache folder and start the log.
%   R = RUN_OPEN(name, S) returns R.dir, R.cache, R.log and starts a diary
%   that appends to R.log. Call RUN_CLOSE(R) at the end.
R.name = name;
R.dir = fullfile(project_root(), 'results', 'runs', name);
R.cache = fullfile(R.dir, 'cache');
if ~exist(R.dir, 'dir'), mkdir(R.dir); end
if ~exist(R.cache, 'dir'), mkdir(R.cache); end
R.log = fullfile(R.dir, 'log.txt');
R.fmt = S.output.matFormat;
diary('off');
diary(R.log);
fprintf('\n==== run %s  started %s ====\n', name, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('MATLAB %s\n', version);
end
