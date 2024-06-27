clear; clc; close all hidden;

% DAQ setup
CYCLES = 240;
traverse_freq = 1.5;
A = 0.10;
SRATE = 20000; % Data sampling rate, Hz
DTOV = 1 / .02; % Conversion factor from distance to voltage, V/m

disp("Setting up DAQ.");
daq_obj = daq("ni");
daq_obj.Rate = SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input_channels = addinput(daq_obj, "Dev2", 0:6, "Voltage");
for i = 1:6
    input_channels(i).Name = "ForceSensor" + i;
end
input_channels(7).Name = "MotorPosition";
pause(1)

disp("Tuning offset");
pause(1)
offset = mean(readwrite(daq_obj, zeros(SRATE * 3, 1), "OutputFormat", "Matrix"));
offset = offset(7);
disp("Offset is " + offset)
pause(1)

time = linspace(0, CYCLES, SRATE * CYCLES);
amplitude = [linspace(0, A, SRATE * 10) linspace(A, A, SRATE * (CYCLES - 20)) linspace(A, 0, SRATE * 10)];

position = amplitude .* sin(2 * pi * traverse_freq * time);
target = DTOV * position;

measured = readwrite(daq_obj, target', "OutputFormat", "Matrix");
mpos = measured(:, 7)' - offset;
% plot(time, mpos / DTOV, time, target / DTOV, time, (mpos - target) / DTOV);
plot(time, (mpos - target) / DTOV);