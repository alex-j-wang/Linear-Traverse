function pwm = to_pwm(thrust)
    A = 0.409E-3;
    B = 140.5E-3;
    C = -0.099 - (thrust / 1.59309598 - 0.099);
    pwm = round(256 * (-B + sqrt(B^2 - 4 * A * C)) / (2 * A));
end

Process.format_plot('Drone PWM Versus Throttle', 'Throttle (%)', 'PWM');
fplot(@(t) to_pwm(t), [0 100]);
ylim([0 65535]);