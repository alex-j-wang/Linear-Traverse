% -------------------------------------------------------------------------
% Plots thrust versus distance at varying frequencies
% -------------------------------------------------------------------------

clear; clc; close all hidden;

Process.format_plot("", "Separation, {\Delta}z/l", "Thrust (AU)");
xlim([0 8]);
ylim([0 1]);
set(gcf, 'Renderer', 'painters');

MAX = 0.594776;
BASE_POINTS = 500;

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
errorbar(est(:, :, 1) / (Config.L / 1000), est(:, :, 2) / MAX, err(:, :, 2) / MAX, 'ko', 'LineWidth', 1.5, 'DisplayName', 'Static');
xlim([0 8]);
ylim([0.55 1.1]);
p = gca();
p.OuterPosition(3) = 0.95;

static = gcf;

%% Dynamic

folder_path = "Data/2024_10_25_3D/processed_data";
base_incr = 10;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

for CF = 54.275
    for SD = [0.5 1 2 3 5 7]
        for A = [2.5 5 7 9]
            fig = copyobj(static, 0);
            for F = [0.2 0.5 1]
                incr = base_incr / F;
                filein = sprintf('CF%g_SD%g_F%g_A%g', CF, SD, F, A);
                load(fullfile(folder_path, filein), 'time', 'forces', 'pos_encoder');
                
                offset = (pos_encoder(end) - pos_encoder(1)) / (length(pos_encoder) - 1) * (0:length(pos_encoder) - 1);
                pos_encoder = pos_encoder - pos_encoder(1) - offset';

                position_fit = fit_sinusoid(time, pos_encoder, A / 100, F);
                distance = SD / 100 + position_fit.A + position_fit(time);
                velocity = differentiate(position_fit, time);

                forces_smoothed = smooth(forces.Total(:, 3), length(forces.Total) / 10) / Config.W / MAX;

                scatter(distance(1:incr:end) / (Config.L / 1000), forces_smoothed(1:incr:end), '.', 'DisplayName', ['F = ' num2str(F)]);
            end
            legend();
            title(sprintf("Thrust Versus Distance (CF%g SD%g A%g)", CF, SD, A));
            fileout = sprintf('/Users/alexwang/Downloads/validation/CF%g_SD%g_A%g.svg', CF, SD, A);
            print(gcf, fileout, "-dsvg");
            close gcf;
        end
    end
end

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype(@(A, C, t) A*sin(2*pi*F*t + C), 'independent', 't', 'coefficients', {'A', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, 0]);
end