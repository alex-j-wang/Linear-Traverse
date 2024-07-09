% Simple readwrite wrapper that automatically performs unit conversions
% and returns position readings in meters
function [data, time] = readposwritepos(daq_obj, position)
    [data, time, ~] = readwrite(daq_obj, position * Config.DTOV, "OutputFormat", "Matrix");
    data(:, 7:end) = data(:, 7:end) * Config.VTOD;
end