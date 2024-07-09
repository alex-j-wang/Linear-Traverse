% Simple readwrite wrapper that automatically performs unit conversions
% and returns current readings in amps
function data = readcurrwritepos(daq_obj, position)
    data = readwrite(daq_obj, position * Config.DTOV, "OutputFormat", "Matrix");
    data(:, 7:end) = data(:, 7:end) * Config.VTOI;
end