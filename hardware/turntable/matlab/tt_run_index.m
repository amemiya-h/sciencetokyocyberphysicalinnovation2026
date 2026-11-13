function log = tt_run_index(port, stepDeg, dwellMs, nSteps, outFile)
%TT_RUN_INDEX  Drive the turntable in index mode and log every dwell.
%   log = tt_run_index("COM5", 1.0, 500, 360, "run01_rig.csv")
%   Start the VHX video first, then call this. Each row of the log is one
%   dwell: [index, t_ms (Arduino clock), pos_steps, theta_deg, pc_time].
%   Sync the Arduino clock to the video with the first motion onset seen in
%   the frames (or film a flash of the shield's LED at start).
arguments
    port (1,1) string
    stepDeg (1,1) double = 1.0
    dwellMs (1,1) double = 500
    nSteps (1,1) double = 360
    outFile (1,1) string = "tt_log.csv"
end
STEPS_PER_REV = 25600;
s = serialport(port, 115200, "Timeout", 30);
configureTerminator(s, "LF");
pause(2);                        % Uno resets when the port opens
flush(s);
writeline(s, "Z");
writeline(s, sprintf("I %.4f %d %d", stepDeg, round(dwellMs), nSteps));
log = zeros(0, 5);
fid = fopen(outFile, "w");
fprintf(fid, "index,t_ms,pos_steps,theta_deg,pc_time\n");
cleanup = onCleanup(@() finish(s, fid));
while true
    ln = strtrim(readline(s));
    if startsWith(ln, "DW,")
        v = sscanf(extractAfter(ln, 3), "%f,%f,%f");     % t, pos, n
        row = [v(3), v(1), v(2), v(2) * 360 / STEPS_PER_REV, posixtime(datetime("now"))];
        log(end+1, :) = row; %#ok<AGROW>
        fprintf(fid, "%d,%d,%d,%.5f,%.3f\n", row);
    elseif startsWith(ln, "DN,") && size(log, 1) >= nSteps
        break
    elseif startsWith(ln, "ERR")
        warning("tt:rig", "%s", ln);
    end
end
end

function finish(s, fid)
try, writeline(s, "S"); catch, end
fclose(fid);
end
