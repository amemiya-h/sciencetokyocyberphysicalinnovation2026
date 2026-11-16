function run_close(R)
%RUN_CLOSE  Finish the log started by RUN_OPEN.
fprintf('==== run %s  finished %s ====\n', R.name, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
diary('off');
end
