% ------------------------------------------------
% Function to format plot labels and properties
% ------------------------------------------------

function formatplot(p_title, p_x, p_y)
    title(p_title);
    xlabel(p_x);
    ylabel(p_y);
    hold on
    grid on
end