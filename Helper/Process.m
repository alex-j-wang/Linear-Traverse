% --------------------------------------
% Class for runtime methods
% --------------------------------------

classdef Process
    methods(Static)
        function formatplot(p_title, p_x, p_y)
            title(p_title);
            xlabel(p_x);
            ylabel(p_y);
            hold on
            grid on
        end
        
        function [data, time] = readsigwritepos(daq_obj, position, mode)
            [data, time, ~] = readwrite(daq_obj, position * Config.DTOV, "OutputFormat", "Matrix");
            if mode == Config.Position
                scale = Config.VTOD;
            else
                scale = Config.VTOI;
            end
            data(:, 7:8) = data(:, 7:8) * scale;
            data(:, 9) = Process.encoder_convert(data(:, 9));
        end

        function to = gradual_move(daq_obj, from, to)
            if from > to + Config.TICKSHIFT
                gradual_shift = Config.DTOV * (from : -Config.TICKSHIFT : to);
                disp("Moving to " + to * 100 + " cm.");
                readwrite(daq_obj, gradual_shift');
            elseif from < to - Config.TICKSHIFT
                gradual_shift = Config.DTOV * (from : +Config.TICKSHIFT : to);
                disp("Moving to " + to * 100 + " cm.");
                readwrite(daq_obj, gradual_shift');
            end
        end

        function encoder_pos = encoder_convert(encoder_data)
            encoder_data = typecast(uint32(encoder_data), 'int32');
            encoder_pos = -double(encoder_data) / Config.LPI * 2.54 / 100;
        end
    end
end