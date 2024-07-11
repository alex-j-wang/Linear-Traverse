% -------------------------------------------------------------------------
% Readwrite wrapper that converts to volts and outputs position in meters
% -------------------------------------------------------------------------

function [data, time] = readposwritepos(daq_obj, position)
    [data, time, ~] = readwrite(daq_obj, position * Config.DTOV, "OutputFormat", "Matrix");
    data(:, 7:8) = data(:, 7:8) * Config.VTOD;
    data(:, 9) = Config.encoder_convert(data(:, 9));
end