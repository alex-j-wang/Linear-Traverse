clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 250;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

title("Crazyflie Thrust Versus Distance and Velocity");
xlabel("Distance (m)");
ylabel("Velocity (m)");
zlabel("Normalized Thrust");
hold on;

for filename = filenames
    load(fullfile(folder_path, filename), 'time', 'forces', 'pos_encoder');
    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;

    if A == 0
        scatter3(SD, 0, mean(forces.Total(:, 3)) / Config.W, 10, 'red', 'filled');
    else
        if abs(mean(pos_encoder)) > 0.01
            continue
        end
        distance = SD + A + pos_encoder(1:incr:end - incr);
        velocity = diff(pos_encoder(1:incr:end)) / incr;
        forces = forces.Total(1:incr:end - incr, 3) / Config.W;
        h = scatter3(distance, velocity, forces, 10, [0 0 SD/0.07], 'filled');
        set(h, 'MarkerEdgeAlpha', 0.3, 'MarkerFaceAlpha', 0.3);
    end
end