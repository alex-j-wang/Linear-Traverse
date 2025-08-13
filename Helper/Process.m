% --------------------------------------
% Class for runtime methods
% --------------------------------------

classdef Process
    methods(Static)
        function serial_callback(src, ~)
            src.UserData.time(end + 1) = datetime('now');
            src.UserData.current(end + 1) = read(src, 1, 'single');
        end

        function [data, time] = conv_readwrite(daq_obj, position, lpi)
            % CONV_READWRITE  Read signal data and write position data with necessary conversions
            s = serialport(Config.ESPCOM, Config.BAUD);
            s.UserData = struct('time', datetime.empty(), 'current', []);
            
            line = readline(s);
            while ~contains(line, 'INA3221 Found!')
                line = readline(s);
            end

            configureCallback(s, 'byte', 4, @Process.serial_callback);
            [data, time] = readwrite(daq_obj, position * Config.DTOV, 'OutputFormat', 'Matrix');
            configureCallback(s, 'off');
            
            data(:, 9) = Process.encoder_convert(data(:, 9), lpi);
            data(:, 10) = Process.encoder_convert(data(:, 10), lpi);
            
            t_serial = seconds(s.UserData.time - s.UserData.time(1));
            data(:, 11) = interp1(t_serial, s.UserData.current, time, 'nearest', 'extrap');
        end

        function [to, encoder] = gradual_move(daq_obj, from, to)
            % GRADUAL_MOVE  Gradually move the traverse to a target position
            if from > to + Config.TICKSHIFT
                gradual_shift = from : -Config.TICKSHIFT : to;
                fprintf('Moving to %g cm.\n', to * 100);
                data = readwrite(daq_obj, gradual_shift' * Config.DTOV, 'OutputFormat', 'Matrix');
                encoder = typecast(uint32(data(:, 9)), 'int32') + typecast(uint32(data(:, 10)), 'int32');
            elseif from < to - Config.TICKSHIFT
                gradual_shift = from : +Config.TICKSHIFT : to;
                fprintf('Moving to %g cm.\n', to * 100);
                data = readwrite(daq_obj, gradual_shift' * Config.DTOV, 'OutputFormat', 'Matrix');
                encoder = typecast(uint32(data(:, 9)), 'int32') + typecast(uint32(data(:, 10)), 'int32');
            end
        end

        function encoder_pos = encoder_convert(encoder_data, lpi)
            % ENCODER_CONVERT  Convert encoder line counts to position data
            encoder_data = typecast(uint32(encoder_data), 'int32');
            encoder_pos = -double(encoder_data) / lpi * 2.54 / 100;
        end

        function position = get_position(daq_obj)
            % GET_POSITION  Estimates the current position of the traverse
            position = zeros(Config.CAL_SAMPLES, 1);
            for i = 1 : Config.CAL_SAMPLES
                position(i) = read(daq_obj).TargetPosition * Config.VTOD;
            end
            position = mean(position);
        end

        function format_plot(p_title, p_x, p_y)
            % FORMAT_PLOT  Format the plot with title, x-axis, y-axis, and grid
            title(p_title, "Interpreter", "latex");
            xlabel(p_x, "Interpreter", "latex");
            ylabel(p_y, "Interpreter", "latex");
            hold on
            grid on
            set(gca,"FontSize", 18)
        end
        
        function run_drone(throttle, varargin)
            % RUN_DRONE  Run at input throttle, excluding drones listed
            disable = strjoin(string(varargin), ' ');
            cmd = sprintf('ssh %s ./throttle.sh %g %s', Config.SSH, throttle, disable);
            runtime = java.lang.Runtime.getRuntime();
            process = runtime.exec(cmd);
            process.waitFor(60, java.util.concurrent.TimeUnit.SECONDS);
            if process.isAlive()
                process.destroyForcibly();
                fprintf('Unable to contact drone. Manually set %g throttle.\n', throttle);
                disp('Press ENTER when ready...');
                loadenv(".env")
                url = getenv("SLACK_WEBHOOK_URL");
                msg = struct('text', 'Unable to contact drone');
                webwrite(url, msg, weboptions('MediaType','application/json'));
                pause;
            end
        end
    end
end