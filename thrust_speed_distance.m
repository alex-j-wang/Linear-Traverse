clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 25;
buf = 51;
MAX = 0.643476;

order = 1;
framelen = 51;

b = sgolay(order,framelen);

items = dir(fullfile(folder_path, '*.mat'));
% filenames = string({items.name});
filenames = ["CF54.275_SD3_F0.2_A7.mat", "CF54.275_SD3_F0.5_A7.mat", "CF54.275_SD3_F1_A7.mat"];

title("Crazyflie Thrust Versus Distance and Velocity");
xlabel("Distance (m)");
ylabel("Velocity (m/s)");
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
        scatter3(main, SD, 0, mean(forces.Total(:, 3)) / Config.W / MAX, 10, 'red', 'filled');
    else
        position_fit = fit_sinusoid(time, pos_encoder, A, F);
        distance = SD + position_fit.A + position_fit(time);
        velocity = differentiate(position_fit, time);
        forces = conv(forces.Total(:, 3), b((framelen + 1) / 2, :)) / Config.W / MAX;
        h = scatter3(main, distance(buf:incr:end-buf), velocity(buf:incr:end-buf), forces(buf:incr:end-buf+1-framelen), 10, 'filled');
        % set(h, 'MarkerEdgeAlpha', 0.1, 'MarkerFaceAlpha', 0.1);
    end
end

legend(main, "F0.2", "F0.5", "F1");

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*t + C)', 'independent', 't', 'coefficients', {'A', 'B', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, F, 0]);
end