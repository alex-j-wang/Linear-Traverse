function data = readwritepos(daq_obj, target)
    readwrite(daq_obj, target', "OutputFormat", "Matrix");
end

COVN = 1 / 0.02; % V/m
DTOV = @(d) d * CONV;
VTOD = @(v) v / CONV;