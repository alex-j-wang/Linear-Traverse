classdef interface
    methods(Static)
        function selection = dropdown(options, title)
            % Create a GUI figure
            screen_size = get(0, 'ScreenSize');
            fig_width = 300;
            fig_height = 150;
            fig_x = (screen_size(3) - fig_width) / 2;
            fig_y = (screen_size(4) - fig_height) / 2;
            fig = uifigure('Name', title, 'Position', [fig_x, fig_y, fig_width, fig_height], ...
                           'CloseRequestFcn', @select);
        
            % Create dropdown menu
            dropdown = uidropdown(fig, 'Items', options, 'Position', [50, 80, 200, 30]);
        
            % Create button
            uibutton(fig, 'Text', 'Select', 'Position', [100, 30, 100, 30], 'ButtonPushedFcn', @select);
        
            selection = '';
            uiwait(fig);
        
            % Callback function for the select button
            function select(~, ~)
                selection = dropdown.Value;
                uiresume(fig);
                delete(fig);
            end
        end

        function dynamic_plotting(folder_path)
            % Create a figure window
            fig = uifigure('Position', [100 100 800 400]);
        
            % Create four dropdown menus
            dropdown1 = uidropdown(fig, 'Position', [10 350 150 30], ...
                'Items', options, ...
                'ValueChangedFcn', @(src, event) updatePlot(dropdown1, dropdown2, dropdown3, dropdown4, ax));
        
            dropdown2 = uidropdown(fig, 'Position', [10 300 150 30], ...
                'Items', options, ...
                'ValueChangedFcn', @(src, event) updatePlot(dropdown1, dropdown2, dropdown3, dropdown4, ax));
        
            dropdown3 = uidropdown(fig, 'Position', [10 250 150 30], ...
                'Items', options, ...
                'ValueChangedFcn', @(src, event) updatePlot(dropdown1, dropdown2, dropdown3, dropdown4, ax));
        
            dropdown4 = uidropdown(fig, 'Position', [10 200 150 30], ...
                'Items', options, ...
                'ValueChangedFcn', @(src, event) updatePlot(dropdown1, dropdown2, dropdown3, dropdown4, ax));
        
            % Create axes for the plot
            ax = uiaxes(fig, 'Position', [200 50 550 300]);
            
            % Initial plot
            updatePlot(dropdown1, dropdown2, dropdown3, dropdown4, ax);
        
            function updatePlot(dropdown1, dropdown2, dropdown3, dropdown4, ax)
                % Get the selected values from the dropdown menus
                selectedValue1 = dropdown1.Value;
                selectedValue2 = dropdown2.Value;
                selectedValue3 = dropdown3.Value;
                selectedValue4 = dropdown4.Value;
        
                % Generate data based on the selected values
                x = linspace(0, 2*pi, 1000);
                y = zeros(size(x)); % Initialize y
        
                % Combine effects of the four dropdowns for the plot
                switch selectedValue1
                    case 'Sine'
                        y = y + sin(x);
                    case 'Cosine'
                        y = y + cos(x);
                    case 'Tangent'
                        y = y + tan(x);
                    % Add other cases if needed
                end
                
                switch selectedValue2
                    case 'Sine'
                        y = y + sin(x);
                    case 'Cosine'
                        y = y + cos(x);
                    case 'Tangent'
                        y = y + tan(x);
                    % Add other cases if needed
                end
                
                switch selectedValue3
                    case 'Sine'
                        y = y + sin(x);
                    case 'Cosine'
                        y = y + cos(x);
                    case 'Tangent'
                        y = y + tan(x);
                    % Add other cases if needed
                end
                
                switch selectedValue4
                    case 'Sine'
                        y = y + sin(x);
                    case 'Cosine'
                        y = y + cos(x);
                    case 'Tangent'
                        y = y + tan(x);
                    % Add other cases if needed
                end
        
                % Update the plot
                plot(ax, x, y);
                title(ax, sprintf('%s, %s, %s, %s', selectedValue1, selectedValue2, selectedValue3, selectedValue4));
                % Limit the y-axis to avoid extreme values for tangent
                if contains(selectedValue1, 'Tangent') || contains(selectedValue2, 'Tangent') || ...
                        contains(selectedValue3, 'Tangent') || contains(selectedValue4, 'Tangent')
                    ax.YLim = [-10 10];
                else
                    ax.YLim = 'auto';
                end
            end
        end
    end
end