clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 500;

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
        distance = SD;
        velocity = 0;
        forces = mean(forces.Total(:, 3)) / Config.W;
    else
        position_fit = fit_sinusoid(time, pos_encoder, A, F);
        if abs(position_fit.D) > 0.01
            continue
        end
        distance = SD - position_fit.D + position_fit.A + position_fit(time);
        velocity = differentiate(position_fit, time);
        forces = forces.Total(:, 3) / Config.W;
    end
    
    % if A == 0
    %     scatter3(distance(1:incr:end), velocity(1:incr:end), forces(1:incr:end), 10, 'red', 'filled');
    % else
    %     h = scatter3(distance(1:incr:end), velocity(1:incr:end), forces(1:incr:end), 10, [0 0 sqrt(SD/0.1)], 'filled');
    %     set(h, 'MarkerEdgeAlpha', 0.3, 'MarkerFaceAlpha', 0.3);
    % end

    if A == 0
        scatter3(distance, 0, forces, 10, 'red', 'filled');
    else
        h = scatter3(SD + A + pos_encoder(1:incr:end - incr), diff(pos_encoder(1:incr:end)) / incr, forces(1:incr:end - incr), 10, [0 0 sqrt(SD/0.1)], 'filled');
        set(h, 'MarkerEdgeAlpha', 0.3, 'MarkerFaceAlpha', 0.3);
    end
end

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);
    
    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*t + C) + D', 'independent', 't', 'coefficients', {'A', 'B', 'C', 'D'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, F, 0, 0]);
end