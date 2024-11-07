clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 25;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

title("Crazyflie Thrust Versus Distance and Velocity");
xlabel("Distance (m)");
ylabel("Velocity (m)");
zlabel("Normalized Thrust");
view(3)
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
        position_fit = fit_sinusoid(time, pos_encoder, A, F);
        distance = SD + position_fit.A + position_fit(time);
        velocity = differentiate(position_fit, time);

        %{
        padding to smooth out points before and after filter and removing
        them later
        %}
        pad_length = 50; %# points to pad
        padded_forces = [forces.Total(:, 3) / Config.W; repmat(forces.Total(end, 3) / Config.W, pad_length, 1)];
        
        %wavelet denoising
        forces_smoothed_padded = wdenoise(padded_forces, 'NoiseEstimate', 'LevelDependent');
        
        % removing earlier padded points here 
        forces_smoothed = forces_smoothed_padded(1:end-pad_length);
        forces_smoothed(end-50:end) = movmean(forces_smoothed(end-50:end), 10);
        h = scatter3(main, distance(1:incr:end), velocity(1:incr:end), forces_smoothed(1:incr:end), 10, 'blue', 'filled');
        set(h, 'MarkerEdgeAlpha', 0.1, 'MarkerFaceAlpha', 0.1);
    end
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