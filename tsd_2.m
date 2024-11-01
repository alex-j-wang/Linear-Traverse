% -------------------------------------------------------------------------
% Plots thrust versus distance with color to represent speed
% -------------------------------------------------------------------------

clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 100;

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
        scatter(SD, mean(forces.Total(:, 3)) / Config.W, 10, 'red', 'filled');
    else
        distance = SD + A + pos_encoder(1:incr:end);
        velocity = diff(distance);
        forces = forces.Total(1:incr:end, 3) / Config.W;
        s = scatter(distance(1:end-1), forces(1:end-1), 10, velocity, 'filled');
        s.MarkerFaceAlpha = 0.1;
    end
end

colorbar;