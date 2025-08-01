clear; clc; close all hidden;

% Load calibration matrix
load(['cal_' Config.SENSOR '.mat']);

% Choose static data folder
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

nfft = Config.SRATE;
window = hamming(nfft);
overlap = nfft / 2;
fmin = 200;
fmax = 350;

figure('Name', 'FFT + PSD Grid', 'Color', 'w', 'Position', [0, 0, 1510 / 2, 900]);
for t = 1:num_trials
    trial = folders{t};
    files = dir(fullfile('Data', folder, trial, '*.mat'));
    filenames = sort({files.name});

    for i = 1:num_sd
        fname = filenames{i};

        load(fullfile('Data', folder, trial, fname), 'audio', 'voltages');

        % Audio
        [P_audio, f_audio] = pwelch(detrend(audio), window, overlap, nfft, Config.SRATE);

        % PSD
        forces = (cal_mat * voltages')';
        [P_force, f_force] = pwelch(detrend(forces(:, 3)), window, overlap, nfft, Config.SRATE);

        audio_mask = f_audio >= fmin & f_audio <= fmax;
        force_mask = f_force >= fmin & f_force <= fmax;
        f_audio_trim = f_audio(audio_mask);
        P_audio_trim = P_audio(audio_mask);
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        idx = (t - 1) * num_sd + i;
        subplot(num_trials, num_sd, idx);

        yyaxis left
        plot(f_audio_trim, 10 * log10(P_audio_trim), 'Color', '#1171BE', 'LineWidth', 1.5);
        ylabel('Audio (dB)', 'Color', '#1171BE');
        
        yyaxis right
        plot(f_force_trim, 10 * log10(P_force_trim), 'Color', '#DD5400', 'LineWidth', 1.5);
        ylabel('Force (dB)', 'Color', '#DD5400');

        xlim([fmin fmax]);
        title(sprintf('%s\nSD=%g', trial, SDS(i) * 100), 'FontSize', 7);
        grid on;
    end
end

sgtitle('Audio FFT & Force PSD', 'FontWeight', 'bold');
exportgraphics(gcf, '/Users/alexwang/Downloads/Y45.svg', 'ContentType', 'vector');