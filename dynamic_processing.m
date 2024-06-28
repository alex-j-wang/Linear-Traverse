% -----------------------------------------------------------------------
% Data Analysis Code for Dynamic Quadrotor Experiments
% -----------------------------------------------------------------------

clear; clc; close all;

SRATE = 20000; % Sampling frequency
FC = 20; % Cut-off frequency

inert = containers.Map();

items = dir();
is_dir = [items.isdir];
dir_names = {items(is_dir).name};
pattern = '^\d{4}_\d{2}_\d{2}$';
matching_folders = dir_names(~cellfun('isempty', regexp(dir_names, pattern)));

folder = interface.dropdown(matching_folders, 'Select a folder');
items = dir(fullfile(folder, "*.mat"));
filenames = sort({items.name});

processed_folder = fullfile(folder, 'processed_data');
if exist(processed_folder, 'dir')
    disp("Processing may overwrite data. Press ENTER to continue...");
    pause;
else
    mkdir(processed_folder);
end

pattern = "CF%d_SD%f_F%f_A%f.mat";

% Create a uifigure
fig = uifigure('Name', 'Dynamic Processing');

% Create the uiprogressdlg
d = uiprogressdlg(fig, 'Title', 'Processing', 'Message', 'Initializing...', 'Indeterminate', 'on');

pause(1); % Simulate some initialization time

d.Indeterminate = 'off';
for i = 1 : length(filenames)
    filename = filenames{i};
    d.Value = (i - 1) / length(filenames);
    d.Message = strrep(filename, '_', ' ');
    
    load(fullfile(folder, filename));

    parameters = num2cell(sscanf(filename, pattern));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;
    T = 1 / F;

    [b, a] = butter(6, FC / (SRATE / 2));
    filtered = zeros(size(forces));
    for col = 1:6
        filtered(:, col) = filtfilt(b, a, forces(:, col));
    end

    % Phase averaged forces
    phase_width = T * SRATE;

    % Check for fractional phase width
    if mod(phase_width, 1) ~= 0
        range = phase_width : phase_width : length(filtered);
        idx = floor(range);
        select = (mod(range, 1) < mod(phase_width, 1));
        keep = true(length(filtered));
        keep(idx(select)) = false;
        filtered = filtered(keep, :);
        motor_position = motor_position(keep);
        phase_width = floor(phase_width);
    end

    stacked = pagetranspose(reshape(filtered', 6, phase_width, []));
    phase_averaged_forces = mean(stacked, 3);
    
    % Phase averaged position
    stacked = reshape(motor_position, phase_width, []);
    motor_position = mean(stacked, 2);

    start = strtok(filename, "_");
    key = extractAfter(filename, start);
    if CF == 0   
        inert(key) = phase_averaged_forces;
    end
    forces = phase_averaged_forces - inert(key);
    save(fullfile(processed_folder, filename), 'time', 'forces', 'motor_position');
end

d.Value = 1;
d.Message = 'All files processed';
pause(3);

close(fig);