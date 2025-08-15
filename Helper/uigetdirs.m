function pathname = uigetdirs(dialog_title)
    % UIGETDIRS  Window for picking multiple directories
    import javax.swing.JFileChooser;

    parent = javaObjectEDT('javax.swing.JFrame');
    parent.setUndecorated(true);
    parent.setAlwaysOnTop(true);
    parent.setLocationRelativeTo([]);
    parent.setVisible(true);
    cleaner = onCleanup(@() parent.dispose());

    jchooser = javaObjectEDT('javax.swing.JFileChooser', pwd);
    jchooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
    if nargin
        jchooser.setDialogTitle(dialog_title);
    end
    jchooser.setMultiSelectionEnabled(true);

    parent.toFront();
    parent.requestFocus();

    status = jchooser.showOpenDialog(parent);

    if status == JFileChooser.APPROVE_OPTION
        pathname = string(jchooser.getSelectedFiles())';
    elseif status == JFileChooser.CANCEL_OPTION
        pathname = [];
    else
        error('Error occurred while picking file.');
    end
end