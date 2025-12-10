% --------------------------------------
% Class for runtime methods
% --------------------------------------

classdef Process
    methods(Static)
        function serial_callback(src, ~)
            while src.NumBytesAvailable >= 9
                byte = read(src, 1, 'uint8');
                if byte ~= 0xAA
                    continue;
                end
                raw = read(src, 2, 'single');
                src.UserData.time(end + 1) = datetime('now');
                src.UserData.current(end + 1, :) = raw(:)';
            end
        end

        function [data, timestamp] = conv_readwrite(daq_obj, position, lpi)
            % CONV_READWRITE  Read signal data and write position data with necessary conversions
            s = serialport(Config.ESPCOM, Config.BAUD);
            s.UserData = struct('time', datetime.empty(), 'current', zeros(0, 2));
            
            line = readline(s);
            while ~contains(line, 'INA3221 Found!')
                line = readline(s);
            end

            configureCallback(s, 'byte', 9, @Process.serial_callback);
            [data, timestamp] = readwrite(daq_obj, position * Config.DTOV);
            configureCallback(s, 'off');

            % TODO: do we still need two encoder channels?
            pos_plus = Process.encoder_convert(data.EncoderPlus, lpi);
            pos_minus = Process.encoder_convert(data.EncoderMinus, lpi);
            data = removevars(data, {'EncoderPlus', 'EncoderMinus'});
            data.Position = pos_plus + pos_minus;
            
            I_interp = interp1(s.UserData.time, s.UserData.current, trigger + data.Time, 'nearest', 'extrap');
            data.LowerCurrent = I_interp(:, 1);
            data.UpperCurrent = I_interp(:, 2);
        end

        function [to, encoder] = gradual_move(daq_obj, from, to)
            % GRADUAL_MOVE  Gradually move the traverse to a target position
            if from > to + Config.TICKSHIFT
                gradual_shift = from : -Config.TICKSHIFT : to;
                fprintf('Moving to %g cm.\n', to * 100);
                data = readwrite(daq_obj, gradual_shift' * Config.DTOV);
                encoder = typecast(uint32(data.EncoderPlus), 'int32') + typecast(uint32(data.EncoderMinus), 'int32');
            elseif from < to - Config.TICKSHIFT
                gradual_shift = from : +Config.TICKSHIFT : to;
                fprintf('Moving to %g cm.\n', to * 100);
                data = readwrite(daq_obj, gradual_shift' * Config.DTOV);
                encoder = typecast(uint32(data.EncoderPlus), 'int32') + typecast(uint32(data.EncoderMinus), 'int32');
            else
                fprintf('Already at %g cm!\n', from * 100);
            end
        end

        function encoder_pos = encoder_convert(encoder_data, lpi)
            % ENCODER_CONVERT  Convert encoder line counts to position data
            encoder_data = typecast(uint32(encoder_data), 'int32');
            encoder_pos = -double(encoder_data) / lpi * 2.54 / 100;
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

        function success = run_drone(throttle, varargin)
            % RUN_DRONE  Run at input throttle, excluding drones listed
            disable = strjoin(string(varargin), ' ');
            cmd = sprintf('ssh %s ./throttle.sh %g %s', Config.SSH, throttle, disable);
            runtime = java.lang.Runtime.getRuntime();
            process = runtime.exec(cmd);
            success = process.waitFor(30, java.util.concurrent.TimeUnit.SECONDS);
            if ~success
                process.destroyForcibly();
                disp('Unable to contact drone.');
                Process.alert_slack('Unable to contact drone');
            end
        end

        function alert_slack(message)
            % ALERT_SLACK  Send a message to Slack via webhook
            loadenv(".env");
            url = getenv("SLACK_WEBHOOK_URL");
            msg = struct('text', message);
            webwrite(url, msg, weboptions('MediaType','application/json'));
        end
    end
end