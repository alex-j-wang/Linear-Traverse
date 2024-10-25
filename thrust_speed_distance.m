clear; clc; close all hidden;

folder_path = "Data/drone-drone-aligned/processed_data";
incr = 100;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

title("Crazyflie Thrust Versus Distance and Velocity");
xlabel("Distance (cm)");
ylabel("Velocity (cm)");
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
        forces = mean(forces.Total(:, 3));
    else
        position_fit = fit_sinusoid(time, pos_encoder - mean(pos_encoder), A, F);
        distance = SD + position_fit(time);
        velocity = differentiate(position_fit, time);
        forces = forces.Total(:, 3) / Config.W;
    end

    h = scatter3(distance(1:incr:end), velocity(1:incr:end), forces(1:incr:end), '.', 'blue');
    % set(h, 'MarkerEdgeAlpha', 0.05, 'MarkerFaceAlpha', 0.05);
end

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);
    
    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*t + C)', 'independent', 't', 'coefficients', {'A', 'B', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, F, 0]);
end