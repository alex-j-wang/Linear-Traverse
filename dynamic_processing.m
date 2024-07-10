% -------------------------------------------------------------------------
% Script for averaging, normalizing, and plotting dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

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

% Create progress bar
fig = uifigure('Name', 'Dynamic Processing');
d = uiprogressdlg(fig, 'Title', 'Processing');

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

    [b, a] = butter(6, FC / (Config.SRATE / 2));
    filtered = zeros(size(forces));
    for col = 1:6
        filtered(:, col) = filtfilt(b, a, forces(:, col));
    end

    % Phase averaged forces
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
        pos_measured = pos_measured(keep);
        phase_width = floor(phase_width);
    end

    stacked = pagetranspose(reshape(filtered', 6, phase_width, []));
    phase_averaged_forces = mean(stacked, 3);
    
    % Phase averaged position
    stacked = reshape(pos_measured, phase_width, []);
    pos_measured = mean(stacked, 2);

    start = strtok(filename, "_");
    key = extractAfter(filename, start);
    if CF == 0   
        inert(key) = phase_averaged_forces;
    end
    forces = phase_averaged_forces - inert(key);
    time = time(1 : length(forces));
    save(fullfile(processed_folder, filename), 'time', 'forces', 'pos_measured');
end

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);

interface.dynamic_plotting(processed_folder, filenames);