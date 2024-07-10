% -------------------------------------------------------------------------
% Readwrite wrapper that converts to volts and outputs position in meters
% -------------------------------------------------------------------------

function [data, time] = readposwritepos(daq_obj, position)
    [data, time, ~] = readwrite(daq_obj, position * Config.DTOV, "OutputFormat", "Matrix");
    data(:, 7:end) = data(:, 7:end) * Config.VTOD;
end