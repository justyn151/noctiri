local runtime = noctalia.getenv("XDG_RUNTIME_DIR")
local stateDir = runtime and (runtime .. "/noctiri-record") or nil
local currentPath = nil

noctalia.setUpdateInterval(1000)
barWidget.setVisible(false)

local function firstLine(value)
    return value and string.match(value, "^([^\r\n]+)") or nil
end

function update()
    if not stateDir then
        barWidget.setVisible(false)
        return
    end

    local pid = firstLine(noctalia.readFile(stateDir .. "/pid"))
    local path = firstLine(noctalia.readFile(stateDir .. "/path"))
    local commandLine = pid and string.match(pid, "^%d+$")
        and noctalia.readFile("/proc/" .. pid .. "/cmdline") or nil
    local recording = path and commandLine
        and string.find(commandLine, path, 1, true) ~= nil

    if recording then
        if currentPath ~= path then
            currentPath = path
            barWidget.setText("● REC")
            barWidget.setColor("error")
            barWidget.setTooltip("Screen recording in progress\nClick to stop and save\n" .. path)
        end
        barWidget.setVisible(true)
    else
        currentPath = nil
        barWidget.setVisible(false)
    end
end

function onClick()
    if currentPath then
        noctalia.runAsync({ noctalia.expandPath("~/.local/bin/noctiri-record"), "stop" })
    end
end

function onIpc(event, _payload)
    if event == "refresh" then
        update()
    end
end
