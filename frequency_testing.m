clear; clc; close all hidden;

% DAQ setup
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

time = linspace(0, 60, SRATE * 60);
amplitude = 0.105;
traverse_freq = linspace(0, 2, SRATE * 60);

phase_in = cumsum(traverse_freq / SRATE);
position = amplitude * sin(2 * pi * phase_in);
target = DTOV * position;

disp("Collecting data.")
measured = readwrite(daq_obj, target', "OutputFormat", "Matrix");
mpos = measured(:, 7)';
plot(time, (mpos - target) / DTOV, time, traverse_freq);

xlabel("Time (s)")