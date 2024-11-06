% -------------------------------------------------------------------------
% Plots thrust versus distance with color to represent speed
% -------------------------------------------------------------------------

clear; clc; close all hidden;

%% Dynamic
folder_path = "Data/2024_10_25_3D/processed_data";
incr = 10;
buf = 300;
MAX = 0.643476;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

Process.format_plot("Crazyflie Thrust Versus Distance", "Distance (m)", "Normalized Thrust");

for filename = filenames
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
        forces = forces.Total(:, 3) / Config.W / MAX;
        s = scatter(distance(buf:incr:end-buf), forces(buf:incr:end-buf), 3, velocity(buf:incr:end-buf), 'filled');
        s.MarkerFaceAlpha = 0.25;
    end
end

colormap(slanCM('jet'));
a = colorbar;
a.Label.String = 'Velocity (m/s)';

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
        
        load(fullfile('Data', '2024_10_31', folder, filename));
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
Process.format_plot("Normalized Force Versus Static Distance", "Distance (m)", "Normalized Force");
errorbar(est(:, :, 1), est(:, :, 2) / MAX, err(:, :, 2) / MAX, 'ko', 'LineWidth', 1.5);

xlim([0 0.26]);
ylim([0.5 1.05]);

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*t + C)', 'independent', 't', 'coefficients', {'A', 'B', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, F, 0]);
end