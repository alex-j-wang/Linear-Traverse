% -------------------------------------------------------------------------
% Script for finding mean and standard deviation of static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% Choose data folder
items = dir('Data');
dir_names = {items([items.isdir]).name};
matching_folders = dir_names(~ismember(dir_names, {'.', '..'}));

folder = interface.dropdown(matching_folders, 'Select a folder');
items = dir(fullfile('Data', folder));
folders = {items([items.isdir]).name};
folders = folders(3:end);

% Assume all folders contain the same number of files
items = dir(fullfile('Data', folder, folders{1}, '*.mat'));
filenames = {items.name};
SDS = sort(cellfun(@(x) str2double(regexp(x, '(?<=SD)[\d\.]+', 'match')), filenames)) / 100;
dummy = array2table(zeros(length(SDS), length(folders) + 1), 'VariableNames', ["SD" string(folders)]);
dummy.SD = SDS';
results = repmat(table(dummy), 1, 6);
results.Properties.VariableNames = Config.NAMES;

% Create progress bar
fig = uifigure('Name', 'Dynamic Processing');
d = uiprogressdlg(fig, 'Title', sprintf('Processing (%s)', folder));
disp(['Processing <strong>' folder '</strong>.']);

for t = 1 : length(folders)
    trial = folders{t};
    items = dir(fullfile('Data', folder, trial, '*.mat'));
    filenames = sort({items.name});
    for i = 1 : length(filenames)
        filename = filenames{i};
        d.Value = ((t - 1) * length(filenames) + (i - 1)) / length(folders) / length(filenames);
        d.Message = [folders{t} ' ' strrep(filename, '_', ' ')];
        
        load(fullfile('Data', folder, trial, filename), 'voltages') % Includes tare
        forces = mean((cal_mat * voltages'), 2)'; % Conversion to forces and moments
        
        % Extract and convert parameters
        parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
        [~, SD, ~, ~] = deal(parameters{:});
        idx = find(SDS == SD / 100);

        for a = 1 : length(Config.NAMES)
            results.(Config.NAMES(a)).(trial)(idx) = forces(a);
        end
    end
end

save(fullfile('Data', folder, 'processed_data.mat'), 'results', '-mat');

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);