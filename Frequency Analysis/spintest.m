% -------------------------------------------------------------------------
% Script to plot FFTs for static data and identify peaks
% -------------------------------------------------------------------------

clear; clc; close all hidden;

CFS = [10 20 30 40 50 60 70];

for idx = 1:7
    CF = CFS(idx);
    load(fullfile('Data', '2025_07_21_STAT', 'CF65', sprintf("CF%g_SD14.25_F1_A0", CF)), 'audio');
    
    % Compute FFT
    N = length(audio);
    Y = fft(audio);
    f = (0:N-1) * (Config.SRATE / N);
    P = abs(Y).^2 / N;
    
    subplot(2, 7, idx);
    title("TRAV " + CF);
    hold on
    grid on
    plot(f, P);
    axis("square");
    xlim([20 500]);
    ax.YTick = [];

    load(fullfile('Data', '2025_07_21_STAT', 'CF67', sprintf("CF%g_SD14.25_F1_A0", CF)), 'audio');
    
    % Compute FFT
    N = length(audio);
    Y = fft(audio);
    f = (0:N-1) * (Config.SRATE / N);
    P = abs(Y).^2 / N;
    
    subplot(2, 7, idx + 7);
    title("FT " + CF);
    hold on
    grid on
    plot(f, P);
    axis("square");
    xlim([20 500]);
    ax.YTick = [];
end
