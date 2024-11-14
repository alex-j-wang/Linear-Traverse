% -------------------------------------------------------------------------
% Plots speed versus distance with color to represent thrust
% -------------------------------------------------------------------------

%% Dynamic
clear; clc; close all hidden;

folder_path = "Data/2024_10_25_3D/processed_data";
incr = 10;
MAX = 0.643476;

items = dir(fullfile(folder_path, '*.mat'));
filenames = string({items.name});

% Crazyflie Thrust Gradient
Process.format_plot("", "{\Delta}z/l", "Velocity (m/s)");

for filename = filenames
    load(fullfile(folder_path, filename), 'time', 'forces', 'pos_encoder');
    parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
    [CF, SD, F, A] = deal(parameters{:});
    SD = SD / 100;
    A = A / 100;

    offset = (pos_encoder(end) - pos_encoder(1)) / (length(pos_encoder) - 1) * (0:length(pos_encoder) - 1);
    pos_encoder = pos_encoder - pos_encoder(1) - offset';

    if A == 0
        scatter(SD, 0, 3, mean(forces.Total(:, 3)) / Config.W / MAX, 'filled');
    else
        position_fit = fit_sinusoid(time, pos_encoder, A, F);
        distance = SD + position_fit.A + position_fit(time);
        velocity = differentiate(position_fit, time);

        %using wavelet denoising to smooth out data
        forces_raw = forces.Total(:, 3) / Config.W / MAX;
        forces_smoothed = wdenoise(forces_raw, 'NoiseEstimate', 'LevelDependent');

        %{
           optional step I considered to remove tangetials, you might want to
        play with this to see which ones to remove without affecting trends
        %}
        
        s = scatter(distance(1:incr:end) / (Config.L / 1000), velocity(1:incr:end), 3, forces_smoothed(1:incr:end), 'filled');
        s.MarkerFaceAlpha = 0.25;
    end
end

colormap(slanCM('jet'));
a = colorbar;
a.Limits = [0.6, 1];
a.Label.Rotation = 270;
a.Label.String = 'Normalized Thrust (F_{z}/W)';

function fitresult = fit_sinusoid(t, s, A, F)
    % Convert to column vectors
    t = t(:);
    s = s(:);

    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*t + C)', 'independent', 't', 'coefficients', {'A', 'B', 'C'});

    % Fit the model to the data
    fitresult = fit(t, s, ft, 'StartPoint', [A, F, 0]);
end