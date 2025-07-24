% -------------------------------------------------------------------------
% Script to plot FFTs for static data and identify peaks
% -------------------------------------------------------------------------

clear; clc; close all hidden;

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

num_sd = length(SDS);
num_trials = length(folders);
fig_fft = figure('Name', 'FFT Peak Visualization', 'Position', [0, 150, 1500, 600], 'Renderer', 'painters');

axes_grid = gobjects(num_trials, num_sd);

for t = 1 : num_trials
    for i = 1 : num_sd
        axes_grid(t, i) = subplot(num_trials, num_sd, (t - 1) * num_sd + i);
    end
end

for t = 1 : num_trials
    trial = folders{t};
    items = dir(fullfile('Data', folder, trial, '*.mat'));
    filenames = sort({items.name});

    for i = 1 : num_sd
        filename = filenames{i};
        ax = axes_grid(t, i);
        load(fullfile('Data', folder, trial, filename), 'audio');

        % Compute FFT
        N = length(audio);
        Y = fft(audio);
        f = (0:N-1) * (Config.SRATE / N);
        P = abs(Y).^2 / N;

        % Trim
        trim = f >= 200 & f <= 500;
        f_trim = f(trim);
        P_trim = P(trim);
        P_trim(1) = 0;

        % Peaks
        [pks, locs] = findpeaks(P_trim, f_trim, ...
            'MinPeakProminence', 5, 'MinPeakDistance', 10, 'SortStr', 'ascend');

        % Plot
        plot(ax, f_trim, 10 * log10(P_trim));
        hold(ax, 'on');

        if ~isempty(locs)
            scatter(ax, locs, 10 * log10(pks), 10, 'r', 'filled');
        end

        % Style
        title(ax, sprintf('Trial: %s\nSD=%g', trial, SDS(i) * 100), 'FontSize', 6, 'Interpreter', 'none');
        xlim(ax, [200 500]);
        ylim(ax, 'auto');
        ax.YTick = [];
    end
end

%% Save
print(gcf, fullfile("~", "Downloads", "FFT.svg"), "-dsvg");