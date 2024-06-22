% -----------------------------------------------------------------------
% Data Analysis Code for Dynamic Quadrotor Experiments
% -----------------------------------------------------------------------

clear; clc; close all;

SRATE = 20000; % Sampling frequency
FC = 20; % Cut-off frequency

function selected_folder = dropdown_folders
    items = dir();
    is_dir = [items.isdir];
    dir_names = {items(is_dir).name};
    pattern = '^\d{4}_\d{2}_\d{2}$';
    matching_folders = dir_names(~cellfun('isempty', regexp(dir_names, pattern)));

    % Create a GUI figure
    screen_size = get(0, 'ScreenSize');
    fig_width = 300;
    fig_height = 150;
    fig_x = (screen_size(3) - fig_width) / 2;
    fig_y = (screen_size(4) - fig_height) / 2;
    fig = figure('Name', 'Select a Folder', 'NumberTitle', 'off', 'Position', [fig_x, fig_y, fig_width, fig_height], ...
                 'MenuBar', 'none', 'ToolBar', 'none', 'CloseRequestFcn', @select);

    % Create buttons
    dropdown = uicontrol('Style', 'popupmenu', 'String', matching_folders, 'Position', [50, 80, 200, 30]);
    uicontrol('Style', 'pushbutton', 'String', 'Select', 'Position', [100, 30, 100, 30], ...
              'Callback', @select);

    selected_folder = '';
    uiwait(fig);

    % Callback function for the select button
    function select(~, ~)
        selected_folder = matching_folders{get(dropdown, 'Value')};
        delete(fig);
        uiresume(fig);
    end
end

inert = containers.Map();

folder = dropdown_folders();
items = dir(folder);
is_file = ~[items.isdir];
filenames = sort({items(is_file).name});

processed_folder = fullfile(folder, 'processed_data');
if exist(processed_folder, 'dir')
    disp("Processing will overwrite data. Press ENTER to continue...");
    pause;
    rmdir(processed_folder, 's');
end
mkdir(processed_folder);

pattern = "CF%d_SD%f_F%f_A%f.mat";
for i = 1 : length(filenames)
    filename = filenames{i};
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
    stacked = pagetranspose(reshape(filtered', 6, T * SRATE, []));
    phase_averaged_forces = mean(stacked, 3);
    stacked = reshape(motor_position, T * SRATE, []);
    
    % Phase averaged position
    pagetranspose(reshape(filtered', 6, t * SRATE, []));
    motor_position = mean(stacked, 2);

    start = strtok(filename, "_");
    key = extractAfter(filename, start);
    if CF == 0   
        inert(key) = phase_averaged_forces;
    else
        forces = phase_averaged_forces - inert(key);
        save(fullfile(folder, processed_folder, filename), 'time', 'forces', 'motor_position');
    end
end