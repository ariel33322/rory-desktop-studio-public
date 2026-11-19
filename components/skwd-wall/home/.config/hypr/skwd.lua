hl.on("hyprland.start", function()
    hl.exec_cmd([["$HOME/.local/share/rory-deck-native/control" start]])
end)
hl.bind("SUPER + W", hl.dsp.exec_cmd([["$HOME/.local/share/rory-deck-native/control" picker]]))
