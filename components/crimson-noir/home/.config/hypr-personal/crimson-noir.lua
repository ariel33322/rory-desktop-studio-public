-- Solo alternar Crimson Noir al soltar Super tras una pulsación breve y sin combinaciones.
do
    local leftSuper, rightSuper = 133, 134 -- XKB: KEY_LEFTMETA/KEY_RIGHTMETA + 8.
    local held = {}
    local heldButtons = {}
    local candidate, pressedAt
    local toggle = [[
        menu="$HOME/crimson-noir/shell.qml"
        qs ipc -p "$menu" call crimsonNoir toggle 2>/dev/null ||
            qs -n -d -p "$menu"
    ]]

    hl.on("hyprland.start", function()
        hl.exec_cmd([[CRIMSON_NOIR_START_HIDDEN=1 qs -n -d -p "$HOME/crimson-noir/shell.qml"]])
    end)

    -- Hyprland entrega la marca monotónica del evento en milisegundos (uint32).
    hl.on("input.keyboard.key", function(key, timeMs, state)
        if state == 1 then
            if (key == leftSuper or key == rightSuper)
                and next(held) == nil and next(heldButtons) == nil then
                candidate, pressedAt = key, timeMs
            else
                candidate = nil
            end
            held[key] = true
        elseif state == 0 then
            held[key] = nil
            local tappedAlone = key == candidate and (timeMs - pressedAt) % 4294967296 < 1000
            candidate = nil
            if tappedAlone then
                hl.exec_cmd(toggle)
            end
        end
    end)

    -- Hyprland 0.56.2 expone los botones mediante atajos no consumidores.
    local mouseOptions = { non_consuming = true, transparent = true, ignore_mods = true,
        submap_universal = true, dont_inhibit = true }
    local releaseOptions = { non_consuming = true, transparent = true, ignore_mods = true,
        submap_universal = true, dont_inhibit = true, release = true }
    for button = 272, 279 do
        local key = "mouse:" .. button
        hl.bind(key, function()
            heldButtons[button] = true
            candidate = nil
        end, mouseOptions)
        hl.bind(key, function()
            heldButtons[button] = nil
        end, releaseOptions)
    end
end
