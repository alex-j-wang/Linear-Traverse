% -------------------------------------------------------------------------
% Readwrite wrapper that converts to volts and outputs current in amps
% -------------------------------------------------------------------------

function [data, time] = readcurrwritepos(daq_obj, position)
    [data, time, ~] = readwrite(daq_obj, position * Config.DTOV, "OutputFormat", "Matrix");
    data(:, 7:8) = data(:, 7:8) * Config.VTOI;
    data(:, 9) = Config.encoder_convert(data(:, 9));
end