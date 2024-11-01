clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

results = zeros([3 10 2]);
folders = ["2024_10_31\T1" "2024_10_31\T2" "2024_10_31\T3"];

% Choose data folder
for f = 1:3
    folder = folders(f);
    items = dir(fullfile('Data', folder, '*.mat'));
    filenames = sort({items.name});

    for i = 1:10
        filename = filenames{i};
        
        load(fullfile('Data', folder, filename));
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
errorbar(est(:, :, 1), est(:, :, 2), err(:, :, 2), 'bo');