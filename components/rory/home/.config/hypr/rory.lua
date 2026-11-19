hl.on("hyprland.start", function()
    hl.exec_cmd([[qs -n -d -p "$HOME/rory-hyprland/shell.qml"]])
end)
hl.bind("SUPER + P", hl.dsp.exec_cmd([[qs ipc -p "$HOME/rory-hyprland/shell.qml" call rory toggleAudioEditor]]))
