function dev = connect(port)
%CONNECT  Open the serial link to the turntable controller (Arduino Uno + CNC shield).
%
%   dev = rig.connect("COM5")
%
%   Talks to hardware/turntable/firmware/tt_firmware (115200 baud, one text
%   command per line). dev is a struct of function handles, so the same
%   scripts run against rig.simulated() when no hardware is attached:
%     dev.send(line)          send one command line
%     dev.receive()           next reply line as char ('' on timeout)
%     dev.setTimeout(seconds) how long receive waits
%     dev.close()             release the port
%
%   Opening the port resets the Uno; this waits for it to boot.

port_ = serialport(port, 115200, 'Timeout', 10);
configureTerminator(port_, 'LF');
pause(2.5);
flush(port_);

dev.send       = @(line) writeline(port_, line);
dev.receive    = @() receiveLine(port_);
dev.setTimeout = @(seconds) setTimeoutOf(port_, seconds);
dev.close      = @() delete(port_);
end


function line = receiveLine(port_)
line = readline(port_);
if isempty(line)
    line = '';
else
    line = char(strtrim(line));
end
end


function setTimeoutOf(port_, seconds)
port_.Timeout = seconds;
end
