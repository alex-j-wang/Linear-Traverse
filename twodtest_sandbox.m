% -------------------------------------------------------------------------
% Plots thrust versus distance with color to represent speed
% -------------------------------------------------------------------------

clear; clc; close all hidden;

Process.format_plot("Static", "{\Delta}z/l", "Thrust");
xlim([0 8]);
ylim([0 1]);

MAX = 0.643476;
SMAX = 0.605;

%% Static

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

results = zeros([3 10 2]);
folders = ["T1", "T2", "T3"];

% Choose data folder
for f = 1:3
    folder = folders(f);
    items = dir(fullfile('Data', '2024_10_31', folder, '*.mat'));
    filenames = sort({items.name});

    for i = 1:10
        filename = filenames{i};
        
        load(fullfile('Data', '2024_10_31', folder, filename), 'voltages');
        forces = (cal_mat * voltages')'; % Conversion to forces and moments
        
        % Extract and convert parameters
        parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
        [~, SD, ~, ~] = deal(parameters{:});
        SD = SD / 100;
        
        Fz = mean(forces(:, 3)) / Config.W;
        results(f, i, 1) = SD;
        results(f, i, 2) = Fz;
    end
end

% Calculate mean and standard deviation
est = mean(results, 1);
err = std(results, 1);

% Plot results (error bars)
static = errorbar(est(:, :, 1) / (Config.L / 1000), est(:, :, 2) / SMAX, err(:, :, 2) / SMAX, 'ko', 'LineWidth', 1.5);
xlim([0 8]);
ylim([0.55 1]);
p = gca();
p.OuterPosition(3) = 0.95;

exportgraphics(gcf, "C:\Users\awang127\Downloads\twodtest\twodtest-static.eps", 'ContentType', 'vector');

%% Dynamic

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 10;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});
highlight = ["CF54.275_SD3_F0.2_A7.mat" "CF54.275_SD3_F1_A7.mat"];

a = colorbar;
a.Label.Rotation = 270;
a.Label.String = 'Velocity (ż/U_i)';
a.Label.FontSize = 18;
a.Limits = [-0.0639 0.0639];
colormap(slanCM('bwr'));

scatter([9 9], [0 0], [1 1], [0.0639 -0.0639]);

title("Low Frequency");

for filename = highlight
    load(fullfile(folder_path, filename), 'time', 'forces', 'pos_encoder');
    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;

    offset = (pos_encoder(end) - pos_encoder(1)) / (length(pos_encoder) - 1) * (0:length(pos_encoder) - 1);
    pos_encoder = pos_encoder - pos_encoder(1) - offset';

    position_fit = fit_sinusoid(time, pos_encoder, A, F);
    distance = SD + position_fit.A + position_fit(time);
    velocity = differentiate(position_fit, time);

    %using wavelet denoising to smooth out data
    forces_raw = forces.Total(:, 3) / Config.W / MAX;
    forces_smoothed = wdenoise(forces_raw, 'NoiseEstimate', 'LevelDependent');

    s = scatter(distance / (Config.L / 1000), forces_smoothed, 3, velocity / Config.U_i, 'filled');
    s.MarkerFaceAlpha = 0.5;

    if filename == "CF54.275_SD3_F0.2_A7.mat"
        exportgraphics(gcf, "C:\Users\awang127\Downloads\twodtest\twodtest-lowfreq.eps", 'ContentType', 'vector');
        title("High Frequency");
    end
end

exportgraphics(gcf, "C:\Users\awang127\Downloads\twodtest\twodtest-highfreq.eps", 'ContentType', 'vector');
title("All Plots");

for filename = filenames

    % Remove outlier
    if filename == "CF54.275_SD2_F1_A9.mat" || ismember(filename, highlight)
        continue
    end

    load(fullfile(folder_path, filename), 'time', 'forces', 'pos_encoder');
    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;

    offset = (pos_encoder(end) - pos_encoder(1)) / (length(pos_encoder) - 1) * (0:length(pos_encoder) - 1);
    pos_encoder = pos_encoder - pos_encoder(1) - offset';

    if A == 0
        % scatter(SD, mean(forces.Total(:, 3)) / Config.W / MAX, 5, 'red', 'filled');
    else
        position_fit = fit_sinusoid(time, pos_encoder, A, F);
        distance = SD + position_fit.A + position_fit(time);
        velocity = differentiate(position_fit, time);

        %using wavelet denoising to smooth out data
        forces_raw = forces.Total(:, 3) / Config.W / MAX;
        forces_smoothed = wdenoise(forces_raw, 'NoiseEstimate', 'LevelDependent');

        s = scatter(distance(1:incr:end) / (Config.L / 1000), forces_smoothed(1:incr:end), 3, velocity(1:incr:end) / Config.U_i, 'filled');
        s.MarkerFaceAlpha = 0.5;
    end
end

chH = get(gca,'Children');
set(gca,'Children',flipud(chH));
exportgraphics(gcf, "C:\Users\awang127\Downloads\twodtest\twodtest-all.pdf", 'ContentType', 'auto');

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*t + C)', 'independent', 't', 'coefficients', {'A', 'B', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, F, 0]);
end