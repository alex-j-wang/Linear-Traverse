clear; clc; close all hidden;

ch6 = "Current Demand";
ch7 = "Current Measured";

% DAQ setup
SRATE = 20000; % Data sampling rate, Hz
ITOV = 1 / .02; % Conversion factor from current to voltage, V/A

disp("Setting up DAQ.");
daq_obj = daq("ni");
daq_obj.Rate = SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input_channels = addinput(daq_obj, "Dev2", 0:7, "Voltage");
for i = 1:6
    input_channels(i).Name = "ForceSensor" + i;
end
input_channels(7).Name = ch6;
input_channels(8).Name = ch7;
pause(1)

time = linspace(0, 60, SRATE * 60);
amplitude = 0.05;
traverse_freq = 0.5;
position = amplitude * sin(2 * pi * traverse_freq * time);
target = DTOV * position;

disp("Collecting data.")
data = readwrite(daq_obj, target', "OutputFormat", "Matrix");
target = data(:, 7)' / DTOV * 100;
measured = data(:, 8)' / DTOV * 100;
save(ch6 + ch7, "target", "measured", '-mat');

formatplot("Comparison of Demanded and Measured Currents", "Time (s)", "Current (A)");
plot(time, target, "DisplayName", "Demanded");
plot(time, measured, "DisplayName", "Measured");
legend();