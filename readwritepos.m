% Simple readwrite wrapper that automatically performs unit conversions
function data = readwritepos(daq_obj, position)
    data = readwrite(daq_obj, DTOV(position), "OutputFormat", "Matrix");
    data(:, 7) = 100 * VTOD(data(:, 7));
end

function v = DTOV(d)
    CONV = 1 / 0.02; % V/m
    v = d * CONV;
end

function d = VTOD(v)
    CONV = 1 / 0.02; % V/m
    d = v / CONV;
end