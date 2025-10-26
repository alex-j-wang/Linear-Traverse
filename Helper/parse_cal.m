% ------------------------------------------------
% Script to convert calibration file to .mat
% ------------------------------------------------

file = uigetfile(".cal");
[~, sensor] = fileparts(file);
disp(['Parsing calibration for ' sensor]);

regex = '(?<=UserAxis Name="[FT][xyz]" values=")[^"]*';
text = fileread(file);
lines = string(regexp(text, regex, 'match'));
matches = squeeze(split(strtrim(lines)));
cal_mat = str2double(matches);

save(['cal_' sensor '.mat'], 'cal_mat');