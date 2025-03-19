% -------------------------------------------------------------------------
% Plots thrust versus distance with color to represent speed
% -------------------------------------------------------------------------

clear; clc; close all hidden;

Process.format_plot("", "Separation, {\Delta}z/l", "Moment, M_y/(Wl)");
% xlim([0 8]); % TODO: set
% ylim([0 1.1]); % TODO: set
axis("square");
set(gcf, 'Renderer', 'painters', 'Position', [100 100 1000 750]);

MAX = 1;
BASE_POINTS = 500;
ERRORBAR = true;

% STATIC_FOLDER = "2025_03_19_STAT";
% DYNAMIC_FOLDER = "2025_03_19_DYN";
STATIC_FOLDER = "2024_12_16_STAT";
DYNAMIC_FOLDER = "2024_12_06_DYN";
OUT_FOLDER = "C:/Users/awang127/Downloads/twodtest-stacked-moment/";

%% Static

load(fullfile('Data', STATIC_FOLDER, 'processed_data'), 'results');
SDS = results.F_z.SD / (Config.L / 1000);
static = table2array(results.M_x(:, 2:end)) / Config.W / (Config.L / 1000) / MAX;

% Calculate mean and standard deviation
est = mean(results, 1);
err = std(results, 1);

if ERRORBAR == true
    % Plot results (error bars)
    errorbar(SDS, mean(static, 2), std(static, 0, 2), 'ko', 'LineWidth', 1.5);
else
    % Plot results (data)
    plot(SDS, static, "kx", "MarkerSize", 8, "LineWidth", 1.5);
end

p = gca();
p.OuterPosition(3) = 0.95;

% print(gcf, fullfile(OUT_FOLDER, "twodtest-static.svg"), "-dsvg");
savefig(gcf, fullfile(OUT_FOLDER, "twodtest-static.fig"));

%% Dynamic

folder_path = fullfile('Data', DYNAMIC_FOLDER, 'processed_data');
incr = 10;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});
highlight = ["CF54.275_SD4_F0.2_A5.mat" "CF54.275_SD4_F1_A5.mat"];

a = colorbar;
a.Label.Rotation = 270;
a.Label.String = 'Velocity ({\Delta}ż/U_i)';
a.Label.FontSize = 18;
colormap(slanCM('coolwarm'));

% Set colormap limits
scatter([9 9], [0 0], [1 1], 2 * pi * 1 * 0.09 / Config.U_i * [1 -1]); % TODO: set

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

    forces_smoothed = smooth(forces.Total(:, 4), length(forces.Total) / 10) / Config.W / (Config.L / 1000) / MAX;

    s = scatter(distance(1:incr:end) / (Config.L / 1000), forces_smoothed(1:incr:end), 3, velocity(1:incr:end) / Config.U_i, 'filled');
    s.MarkerFaceAlpha = 0.5;

    if filename == highlight(1)
        % print(gcf, fullfile(OUT_FOLDER, "twodtest-lowfreq.svg"), "-dsvg");
        savefig(gcf, fullfile(OUT_FOLDER, "twodtest-lowfreq.fig"));
    end
end

% print(gcf, fullfile(OUT_FOLDER, "twodtest-highfreq.svg"), "-dsvg");
savefig(gcf, fullfile(OUT_FOLDER, "twodtest-highfreq.fig"));

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

    forces_smoothed = smooth(forces.Total(:, 4), length(forces.Total) / 10) / Config.W / (Config.L / 1000) / MAX;
    
    idx = floor(linspace(1, length(distance), BASE_POINTS * A / 0.05));
    s = scatter(distance(idx) / (Config.L / 1000), forces_smoothed(idx), 3, velocity(idx) / Config.U_i, 'filled');
    s.MarkerFaceAlpha = 0.5;
    
    % if any(abs(distance(idx) / (Config.L / 1000) - 3.11231) < 0.0001 & abs(forces_smoothed(idx) - 0.900324) < 0.0001)
    %     disp(filename)
    % end
end

% lines = get(gca, 'Children');
% uistack(lines(end), 'top');
chH = get(gca,'Children');
set(gca,'Children',flipud(chH));

% print(gcf, fullfile(OUT_FOLDER, "twodtest-all.svg"), "-dsvg");
savefig(gcf, fullfile(OUT_FOLDER, "twodtest-all.fig"));

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype(@(A, C, t) A*sin(2*pi*F*t + C), 'independent', 't', 'coefficients', {'A', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, 0]);
end