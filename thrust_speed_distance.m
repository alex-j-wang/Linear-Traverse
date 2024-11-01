clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 25;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

title("Crazyflie Thrust Versus Distance and Velocity");
xlabel("Distance (m)");
ylabel("Velocity (m)");
zlabel("Normalized Thrust");
hold on;

main = gca;

figure
Process.format_plot("Phase Averaged Position Versus Time (Raw)", "Time (s)", "Position (m)");
raw = gca;
figure
Process.format_plot("Phase Averaged Position Versus Time (Shifted)", "Time (s)", "Position (m)");
shifted = gca;

for filename = filenames
    load(fullfile(folder_path, filename), 'time', 'forces', 'pos_encoder');
    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;

    plot(raw, time, pos_encoder);
    offset = (pos_encoder(end) - pos_encoder(1)) / (length(pos_encoder) - 1) * (0:length(pos_encoder) - 1);
    pos_encoder = pos_encoder - pos_encoder(1) - offset';
    plot(shifted, time, pos_encoder);

    if A == 0
        scatter3(main, SD, 0, mean(forces.Total(:, 3)) / Config.W, 10, 'red', 'filled');
    else
        distance = SD + A + pos_encoder(1:incr:end - incr);
        velocity = diff(pos_encoder(1:incr:end)) / incr;
        forces = forces.Total(1:incr:end - incr, 3) / Config.W;
        h = scatter3(main, distance(10:end-10), velocity(10:end-10), forces(10:end-10), 10, [0 0 SD/0.07], 'filled');
        set(h, 'MarkerEdgeAlpha', 0.1, 'MarkerFaceAlpha', 0.1);
    end
end