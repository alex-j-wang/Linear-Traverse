clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% Files to process
filenames = {
    'CF0_SD3.5_F1_A0.mat', ...
    'CF54.275_SD3.5_F1_A0.mat', ...
    'FT_CF54.275_SD3.5_F1_A0.mat', ...
    'TRAV_CF54.275_SD3.5_F1_A0.mat', ...
    'CF0_SD28_F1_A0.mat', ...
    'CF54.275_SD28_F1_A0.mat', ...
    'FT_CF54.275_SD28_F1_A0.mat', ...
    'TRAV_CF54.275_SD28_F1_A0.mat'
};

% Title map
titles = containers.Map( ...
    filenames, ...
    { ...
    'Room (SD3.5)', ...
    'Both (SD3.5)', ...
    'Transducer Only (SD3.5)', ...
    'Traverse Only (SD3.5)', ...
    'Room (SD28)', ...
    'Both (SD28)', ...
    'Transducer Only (SD28)', ...
    'Traverse Only (SD28)' ...
    } ...
);

% Preallocate limits
min_fft = inf; max_fft = -inf;
min_psd = inf; max_psd = -inf;

fft_data = cell(1, length(filenames));
psd_data = cell(1, length(filenames));
fft_freqs = cell(1, length(filenames));
psd_freqs = cell(1, length(filenames));

% First pass: compute limits
for i = 1:length(filenames)
    fname = filenames{i};
    load(fullfile('Data', '2025_07_21_STAT_AUDIO', fname), 'audio', 'voltages');

    % Compute FFT
    w = hamming(10000);
    [P_fft, f_fft] = pwelch(audio, w, 5000, Config.SRATE / 2, Config.SRATE, 'ConfidenceLevel', 0.95);
    
    % Compute PSD
    forces = (cal_mat * voltages')';
    [P_psd, f_psd] = pwelch(forces(:, 3), w, 5000, Config.SRATE / 2, Config.SRATE, 'ConfidenceLevel', 0.95);

    % Store for second pass
    fft_data{i} = P_fft;
    psd_data{i} = P_psd;
    fft_freqs{i} = f_fft;
    psd_freqs{i} = f_psd;

    % Track global min/max (skip 0s for log)
    P_fft_nonzero = P_fft(P_fft > 0 & f_fft >= 100 & f_fft <= 500);
    P_psd_nonzero = P_psd(P_psd > 0 & f_psd >= 100 & f_psd <= 500);

    min_fft = min([min_fft, min(P_fft_nonzero)]);
    max_fft = max([max_fft, max(P_fft_nonzero)]);
    min_psd = min([min_psd, min(P_psd_nonzero)]);
    max_psd = max([max_psd, max(P_psd_nonzero)]);
end

min_fft = 10 * log10(min_fft);
max_fft = 10 * log10(max_fft);
min_psd = 10 * log10(min_psd);
max_psd = 10 * log10(max_psd);

% Second pass: plot
figure('Name', 'Audio & Force Analysis', 'Color', 'w');
for i = 1:length(filenames)
    subplot(2, 4, i);
    yyaxis left
    plot(fft_freqs{i}, 10 * log10(fft_data{i}), 'Color', '#1171BE');
    ylabel('Audio (dB)', 'Color', '#1171BE');
    ylim([min_fft, max_fft]);
    xlim([100 500]);

    yyaxis right
    plot(psd_freqs{i}, 10 * log10(psd_data{i}), 'Color', '#DD5400');
    ylabel('Force (dB)', 'Color', '#DD5400');
    ylim([min_psd, max_psd]);

    title(titles(filenames{i}), 'Interpreter', 'none');
end

sgtitle('Audio & Force Analysis', 'FontWeight', 'bold');