% -------------------------------------------------------------------------
% Script for finding mean and standard deviation of static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% Choose data folder
folder = uigetdir();
[~, foldername, ~] = fileparts(folder);
items = dir(folder);
folders = {items([items.isdir]).name};
folders = folders(3:end);

% Assume all folders contain the same number of files
items = dir(fullfile(folder, folders{1}, '*.mat'));
filenames = {items.name};
SDS = sort(cellfun(@(x) str2double(regexp(x, '(?<=SD)[\d\.]+', 'match')), filenames)) / 100;
dummy = array2table(zeros(length(SDS), length(folders) + 1), 'VariableNames', ["SD" string(folders)]);
dummy.SD = SDS';
results = repmat(table(dummy), 1, 8);
results.Properties.VariableNames = [Config.NAMES "Current" "Transducer RPS"];

% Create progress bar
fig = uifigure('Name', 'Static Processing');
d = uiprogressdlg(fig, 'Title', sprintf('Processing (%s)', foldername));
disp(['Processing <strong>' foldername '</strong>.']);

% Current analysis parameters
cmin = 1e-3;
cmax = 5;

% Frequency analysis parameters
nfft = Config.SRATE;
window = hamming(nfft);
overlap = nfft / 2;
fmin = 200;
fmax = 350;

num_trials = length(folders);
num_sd = length(SDS);

for t = 1 : length(folders)
    trial = folders{t};
    items = dir(fullfile(folder, trial, '*.mat'));
    filenames = sort({items.name});
    for i = 1 : length(filenames)
        filename = filenames{i};
        d.Value = ((t - 1) * length(filenames) + (i - 1)) / length(folders) / length(filenames);
        d.Message = [folders{t} ' ' strrep(filename, '_', ' ')];

        load(fullfile(folder, trial, filename), 'voltages', 'cf_current', 'audio') % Includes tare
        forces = (cal_mat * voltages')'; % Conversion to forces and moments

        % Extract and convert parameters
        parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
        [~, SD, ~, ~] = deal(parameters{:});
        idx = find(SDS == SD / 100);

        for a = 1 : length(Config.NAMES)
            results.(Config.NAMES(a)).(trial)(idx) = mean(forces(:, a));
        end

        % Mean current
        current_mask = cf_current >= cmin & cf_current <= cmax;
        results.Current.(trial)(idx) = mean(cf_current(current_mask));

        % Frequency analysis
        [P_force, f_force] = pwelch(forces(:, 3), window, overlap, nfft, Config.SRATE);
        force_mask = f_force >= fmin & f_force <= fmax;
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        [~, loc] = max(P_force_trim);
        transducer_rps = f_force_trim(loc);
        results.("Transducer RPS").(trial)(idx) = transducer_rps;

        idx = (t - 1) * num_sd + find(SDS == SD / 100);
        subplot(num_trials, num_sd, idx);
        hold on;
        plot(f_force_trim, 10 * log10(P_force_trim), 'r');
        xline(transducer_rps, 'g--', 'LineWidth', 1.5);
        title("T" + t + " SD" + SD);
        xlim([fmin fmax]);
    end
end

save(fullfile(folder, 'processed_data.mat'), 'results', '-mat');

set(gcf, 'Renderer', 'painters');
print(gcf, fullfile(folder, "frequency.svg"), "-dsvg");

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);