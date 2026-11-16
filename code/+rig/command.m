function lines = command(dev, line, doneTag, timeoutSeconds)
%COMMAND  Send one command and wait for the reply that ends it.
%
%   lines = rig.command(dev, 'M 90', 'DN', 30)
%
%   doneTag         start of the reply that means "finished": 'OK' for
%                   settings, 'DN' for a rotation, 'OK,Y' for a radial move
%   timeoutSeconds  give up after this long without that reply
%   lines           every reply line received, the final one last
%
%   An ERR reply, or silence, raises an error.

if nargin < 4
    timeoutSeconds = 10;
end
dev.setTimeout(timeoutSeconds);
dev.send(line);
lines = {};
while true
    reply = dev.receive();
    if isempty(reply)
        error('rig:noReply', 'No "%s" reply to "%s" within %.0f s.', doneTag, line, timeoutSeconds);
    end
    lines{end + 1} = reply; %#ok<AGROW>
    if strncmp(reply, 'ERR', 3)
        error('rig:refused', 'The controller answered "%s" to "%s".', reply, line);
    end
    if strncmp(reply, doneTag, numel(doneTag))
        return
    end
end
end
