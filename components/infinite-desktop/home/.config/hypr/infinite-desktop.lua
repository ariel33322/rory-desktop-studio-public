local scripts = [["$HOME/Infinite-Desktop/bin/]]

hl.bind("SUPER + Left",  hl.dsp.exec_cmd("python3 " .. scripts .. 'navigate_windows.py" left'))
hl.bind("SUPER + Right", hl.dsp.exec_cmd("python3 " .. scripts .. 'navigate_windows.py" right'))
hl.bind("SUPER + Up",    hl.dsp.exec_cmd("python3 " .. scripts .. 'navigate_windows.py" up'))
hl.bind("SUPER + Down",  hl.dsp.exec_cmd("python3 " .. scripts .. 'navigate_windows.py" down'))
hl.bind("SUPER + D",    hl.dsp.exec_cmd("python3 " .. scripts .. 'floating_tile_toggle.py"'))

local function zoom(direction)
    local workspace = hl.get_active_workspace()
    if not workspace then return { pass_event = true } end

    local stateFile = io.open("/tmp/floating_tile_state.json", "r")
    if not stateFile then return { pass_event = true } end
    local state = stateFile:read("*a")
    stateFile:close()
    -- El script escribe el modo como primer campo de cada escritorio.
    local prefix = '\n  "' .. workspace.id .. '": {\n    "mode": "floating"'
    if not state:find(prefix, 1, true) then return { pass_event = true } end

    local cursor = hl.get_cursor_pos()
    hl.exec_cmd("python3 " .. scripts .. 'floating_tile_toggle.py" --zoom ' ..
        string.format("%s %d %.0f %.0f", direction, workspace.id, cursor.x, cursor.y) ..
        ' 2>> "$XDG_RUNTIME_DIR/infinite-desktop.log"')
end

hl.bind("CTRL + mouse_up", function() return zoom("in") end)
hl.bind("CTRL + mouse_down", function() return zoom("out") end)

hl.on("window.open", function(window)
    local address = window.address
    local workspace = window.workspace
    if workspace and address and address:match("^0x%x+$") then
        hl.exec_cmd("python3 " .. scripts .. 'floating_tile_toggle.py" --window ' ..
            address .. ' ' .. workspace.id .. ' 2>> "$XDG_RUNTIME_DIR/infinite-desktop.log"')
    end
end)

hl.on("hyprland.start", function()
    hl.exec_cmd([[
        if ! pgrep -u "$(id -u)" -f '^(/usr/bin/)?python3 ([^ ]*/)?infinite_desktop_core[.]py( |$)' >/dev/null; then
            exec flock -n -F "$XDG_RUNTIME_DIR/infinite-desktop.lock" \
                python3 -u "$HOME/Infinite-Desktop/bin/infinite_desktop_core.py" 1.6 \
                >> "$XDG_RUNTIME_DIR/infinite-desktop.log" 2>&1
        fi
    ]])
end)
