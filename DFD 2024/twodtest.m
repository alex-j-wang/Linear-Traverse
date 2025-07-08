% -------------------------------------------------------------------------
% Plots thrust versus distance with color to represent speed
% -------------------------------------------------------------------------

clear; clc; close all hidden;

Process.format_plot("", "Separation, $\Delta z/l$", "Thrust, $\bar{F_z}/W$");
xlim([0 8]);
ylim([0.5 1.4]);
axis("square");
set(gcf, 'Renderer', 'painters', 'Position', [100 100 1000 750]);

MAX = 1;
MAX_STATIC = 1;
BASE_POINTS = 500;
ERRORBAR = true;

% STATIC_FOLDER = "2024_12_16_STAT";
% DYNAMIC_FOLDER = "2024_12_06_DYN";
STATIC_FOLDER = "2025_03_19_STAT";
DYNAMIC_FOLDER = "2025_03_19_DYN";

OUT_FOLDER = "/Users/awang127/Downloads/twodtest-offset-force";

%% Static

load(fullfile('Data', STATIC_FOLDER, 'processed_data'), 'results');
SDS = results.F_z.SD / (Config.L / 1000);
static = table2array(results.F_z(:, 2:end)) / Config.W / MAX_STATIC;

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
% highlight = ["CF54.275_SD4_F0.2_A5.mat" "CF54.275_SD4_F1_A5.mat"];
highlight = [""];

a = colorbar;
a.Label.Rotation = 270;
a.Label.String = 'Velocity $(\Delta \dot{z}/U_i)$';
a.Label.FontSize = 18;
a.Label.Interpreter = "latex";
colormap(slanCM('coolwarm'));

% Set colormap limits
scatter([9 9], [0 0], [1 1], 2 * pi * 1 * 0.09 / Config.U_i * [1 -1]);

for filename = highlight
    if filename == ""
        break
    end
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
        % print(gcf, fullfile(OUT_FOLDER, "twodtest-lowfreq.svg"), "-dsvg");
        savefig(gcf, fullfile(OUT_FOLDER, "twodtest-lowfreq.fig"));
    end
end

% print(gcf, fullfile(OUT_FOLDER, "twodtest-highfreq.svg"), "-dsvg");
savefig(gcf, fullfile(OUT_FOLDER, "twodtest-highfreq.fig"));

case_all = {};
distance_all = [];
thrust_all = [];
velocity_all = [];

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

    case_all = [case_all; repmat(filename, [length(idx) 1])];
    distance_all = [distance_all; distance(idx) / (Config.L / 1000)];
    thrust_all = [thrust_all; forces_smoothed(idx)];
    velocity_all = [velocity_all; velocity(idx) / Config.U_i];
    
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

static = results.F_z;
dynamic = table(case_all, distance_all, thrust_all, velocity_all, ...
    'VariableNames', {'case' 'distance' 'thrust' 'velocity'});
save(fullfile(OUT_FOLDER, "twodtest-all.mat"), 'static', 'dynamic');

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype(@(A, C, t) A*sin(2*pi*F*t + C), 'independent', 't', 'coefficients', {'A', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, 0]);
end