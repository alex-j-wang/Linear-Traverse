clear; clc; close all hidden;

% Load calibration matrix
load(['cal_' Config.SENSOR '.mat']);

% Choose data folder
items = dir('Data');
dir_names = {items([items.isdir]).name};
matching_folders = dir_names(~ismember(dir_names, {'.', '..'}));

folder = interface.dropdown(matching_folders, 'Select a folder');
items = dir(fullfile('Data', folder));
folders = {items([items.isdir]).name};
folders = folders(3:end);

% Assume all folders contain the same files
files = dir(fullfile('Data', folder, folders{1}, '*.mat'));
filenames = sort({files.name});
SDS = sort(cellfun(@(x) str2double(regexp(x, '(?<=SD)[\d\.]+', 'match')), filenames)) / 100;

num_trials = length(folders);
num_sd = length(SDS);

% Preallocate for min/max tracking
min_fft = inf; max_fft = -inf;
min_psd = inf; max_psd = -inf;

fft_data = cell(num_trials, num_sd);
psd_data = cell(num_trials, num_sd);
fft_freqs = cell(num_trials, num_sd);
psd_freqs = cell(num_trials, num_sd);
labels = strings(num_trials, num_sd);

% First pass: compute and store everything
w = hamming(10000);
for t = 1:num_trials
    trial = folders{t};
    files = dir(fullfile('Data', folder, trial, '*.mat'));
    filenames = sort({files.name});

    for i = 1:num_sd
        fname = filenames{i};
        labels(t, i) = sprintf('%s\nSD=%g', trial, SDS(i) * 100);

        load(fullfile('Data', folder, trial, fname), 'audio', 'voltages');

        % FFT (Welch)
        [P_fft, f_fft] = pwelch(audio, w, 5000, Config.SRATE / 2, Config.SRATE);

        % PSD
        forces = (cal_mat * voltages')';
        [P_psd, f_psd] = pwelch(forces(:, 3), w, 5000, Config.SRATE / 2, Config.SRATE);

        fft_data{t, i} = P_fft;
        fft_freqs{t, i} = f_fft;
        psd_data{t, i} = P_psd;
        psd_freqs{t, i} = f_psd;

        % Min/max (skip 0s)
        P_fft_valid = P_fft(P_fft > 0 & f_fft >= 100 & f_fft <= 500);
        P_psd_valid = P_psd(P_psd > 0 & f_psd >= 100 & f_psd <= 500);
        min_fft = min(min_fft, min(P_fft_valid));
        max_fft = max(max_fft, max(P_fft_valid));
        min_psd = min(min_psd, min(P_psd_valid));
        max_psd = max(max_psd, max(P_psd_valid));
    end
end

% Convert to log scale
min_fft = 10 * log10(min_fft); max_fft = 10 * log10(max_fft);
min_psd = 10 * log10(min_psd); max_psd = 10 * log10(max_psd);

% Plotting
figure('Name', 'FFT + PSD Grid', 'Color', 'w', 'Position', [0, 100, 1600, 900]);
for t = 1:num_trials
    for i = 1:num_sd
        idx = (t - 1) * num_sd + i;
        subplot(num_trials, num_sd, idx);

        yyaxis left
        plot(fft_freqs{t, i}, 10 * log10(fft_data{t, i}), 'Color', '#1171BE');
        ylabel('Audio (dB)', 'Color', '#1171BE');
        ylim([min_fft, max_fft]);
        xlim([100, 500]);

        yyaxis right
        plot(psd_freqs{t, i}, 10 * log10(psd_data{t, i}), 'Color', '#DD5400');
        ylabel('Force (dB)', 'Color', '#DD5400');
        ylim([min_psd, max_psd]);

        title(labels(t, i), 'FontSize', 7, 'Interpreter', 'none');
        grid on;
    end
end

sgtitle(sprintf('Audio FFT & Force PSD — Folder: %s', folder), 'FontWeight', 'bold');