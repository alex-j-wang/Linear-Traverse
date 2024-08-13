% -------------------------------------------------------------------------
% Script for averaging, normalizing, and plotting dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% Map for storing inertial data
inert = containers.Map();

% Choose data folder
items = dir('Data');
is_dir = [items.isdir];
dir_names = {items(is_dir).name};
matching_folders = dir_names(~ismember(dir_names, {'.', '..'}));

folder = interface.dropdown(matching_folders, 'Select a folder');
items = dir(fullfile('Data', folder, '*.mat'));
filenames = sort({items.name});

% Set up processed data folder
processed_folder = fullfile('Data', folder, 'processed_data');
if exist(processed_folder, 'dir')
    reprocess = input('Skip files that have already been converted [y/n]? ', 's') ~= 'y';
else
    mkdir(processed_folder);
    reprocess = true;
end

% Create progress bar
fig = uifigure('Name', 'Dynamic Processing');
d = uiprogressdlg(fig, 'Title', 'Processing');

for i = 1 : length(filenames)
    filename = filenames{i};
    d.Value = (i - 1) / length(filenames);
    d.Message = strrep(filename, '_', ' ');
    
    if ~reprocess && isfile(fullfile(processed_folder, filename))
        continue;
    end
    
    load(fullfile('Data', folder, filename));
    forces = (cal_mat * voltages')'; % Conversion to forces and moments
    tare_forces = (cal_mat * tare_voltages')'; % Conversion to forces and moments

    % Extract and convert parameters
    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;
    T = 1 / F;
    % FC = Config.FCM * F;
    FC = 20;

    % Apply Butterworth filter
    [b, a] = butter(6, FC / (Config.SRATE / 2));
    filtered = zeros(size(forces));
    for col = 1:6
        filtered(:, col) = filtfilt(b, a, forces(:, col));
    end

    % Phase average forces
    phase_width = T * Config.SRATE;
    frac = mod(phase_width, 1);

    % Check for fractional phase width, eliminate entries to support integral phase width
    if frac ~= 0
        range = phase_width : phase_width : length(filtered) + 1;
        select = mod(frac * (1 : length(range)), 1) < frac;
        range = floor(range);
        keep = true(1, length(filtered));
        keep(range(select)) = false;
        filtered = filtered(keep, :);
        pos_encoder = pos_encoder(keep);
        phase_width = floor(phase_width);
    end

    stacked = pagetranspose(reshape(filtered', 6, phase_width, []));
    total_force = mean(stacked, 3);
    stdev = std(stacked, 0, 3);
    
    % Phase average position
    stacked = reshape(pos_encoder, phase_width, []);
    pos_encoder = mean(stacked, 2);

    % Retrieve inertial, calculate lift, save data
    start = strtok(filename, '_');
    key = extractAfter(filename, start);
    if CF == 0   
        inert(key) = total_force;
    end
    inertial_force = inert(key);
    lift_force = total_force - inertial_force;
    forces = table(total_force, inertial_force, lift_force, 'VariableNames', Config.BOXES(1:3));
    time = time(1 : length(total_force));
    save(fullfile(processed_folder, filename), 'time', 'forces', 'tare_forces', 'pos_encoder', 'stdev');
end

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);

interface.dynamic_plotting(processed_folder, filenames);