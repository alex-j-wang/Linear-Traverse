% -------------------------------------------------------------------------
% Plots thrust versus distance with color to represent speed
% -------------------------------------------------------------------------

clear; clc; close all hidden;

Process.format_plot("", "Separation, {\Delta}z/l", "Thrust (AU)");
xlim([0 8]);
% ylim([0 1.1]);
axis("square");
set(gcf, 'Renderer', 'painters', 'Position', [100 100 1000 750]);

% MAX = 0.7;
MAX = 1;
BASE_POINTS = 500;
ERRORBAR = true;

STATIC_FOLDER = "2024_12_09_STAT";
DYNAMIC_FOLDER = "2024_12_06_DYN";
OUT_FOLDER = "/Users/alexwang/Downloads/twodtest";

%% Static

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

items = dir(fullfile('Data', STATIC_FOLDER));
folders = string({items(3:end).name});
results = zeros([length(folders) 10 2]);

% Choose data folder
for f = 1:length(folders)
    folder = folders(f);
    items = dir(fullfile('Data', STATIC_FOLDER, folder, '*.mat'));
    filenames = sort({items.name});

    for i = 1:10
        filename = filenames{i};
        
        load(fullfile('Data', STATIC_FOLDER, folder, filename), 'voltages');
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

if ERRORBAR
    % Plot results (error bars)
    errorbar(est(:, :, 1) / (Config.L / 1000), est(:, :, 2) / MAX, err(:, :, 2) / MAX, 'ko', 'LineWidth', 1.5);
else
    % Plot results (data)
    SD = results(:, :, 1);
    Fz = results(:, :, 2);
    plot(SD(:) / (Config.L / 1000), Fz(:) / MAX, "kx", "MarkerSize", 8, "LineWidth", 1.5);
end

p = gca();
p.OuterPosition(3) = 0.95;

print(gcf, fullfile(OUT_FOLDER, "twodtest-static.svg"), "-dsvg");

%% Dynamic

folder_path = fullfile('Data', DYNAMIC_FOLDER, 'processed_data');
incr = 10;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});
highlight = ["CF54.275_SD5_F0.1_A5.mat" "CF54.275_SD5_F1_A5.mat"];

a = colorbar;
a.Label.Rotation = 270;
a.Label.String = 'Velocity ({\Delta}ż/U_i)';
a.Label.FontSize = 18;
colormap(slanCM('coolwarm'));

% Set colormap limits
scatter([9 9], [0 0], [1 1], 2 * pi * 1 * 0.09 / Config.U_i * [1 -1]);

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

    forces_smoothed = smooth(forces.Total(:, 3), length(forces.Total) / 10) / Config.W / MAX;

    s = scatter(distance(1:incr:end) / (Config.L / 1000), forces_smoothed(1:incr:end), 3, velocity(1:incr:end) / Config.U_i, 'filled');
    s.MarkerFaceAlpha = 0.5;

    if filename == highlight(1)
        print(gcf, fullfile(OUT_FOLDER, "twodtest-lowfreq.svg"), "-dsvg");
    end
end

print(gcf, fullfile(OUT_FOLDER, "twodtest-highfreq.svg"), "-dsvg");

for filename = filenames

    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;

    if A == 0 || ismember(filename, highlight)
        continue
    end

    load(fullfile(folder_path, filename), 'time', 'forces', 'pos_encoder');

    offset = (pos_encoder(end) - pos_encoder(1)) / (length(pos_encoder) - 1) * (0:length(pos_encoder) - 1);
    pos_encoder = pos_encoder - pos_encoder(1) - offset';

    position_fit = fit_sinusoid(time, pos_encoder, A, F);
    distance = SD + position_fit.A + position_fit(time);
    velocity = differentiate(position_fit, time);

    forces_smoothed = smooth(forces.Total(:, 3), length(forces.Total) / 10) / Config.W / MAX;
    
    idx = floor(linspace(1, length(distance), BASE_POINTS * A / 0.05));
    s = scatter(distance(idx) / (Config.L / 1000), forces_smoothed(idx), 3, velocity(idx) / Config.U_i, 'filled');
    s.MarkerFaceAlpha = 0.5;
end

lines = get(gca, 'Children');
uistack(lines(end), 'top');
print(gcf, fullfile(OUT_FOLDER, "twodtest-all.svg"), "-dsvg");

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype(@(A, C, t) A*sin(2*pi*F*t + C), 'independent', 't', 'coefficients', {'A', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, 0]);
end