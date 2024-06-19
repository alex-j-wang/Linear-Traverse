clear; clc; close all;

% Set sensor model
SENSOR = 'FT21128';

regex = '(?<=UserAxis Name="[FT][xyz]" values=")[^"]*';
text = fileread([SENSOR '.cal']);
lines = string(regexp(text, regex, "match"));
matches = squeeze(split(strtrim(lines)));
cal_mat = str2double(matches);

save(['cal_' SENSOR '.mat'], "cal_mat");