pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

// Tracks visible client coverage per Hyprland output. State is event driven;
// the bounded fallback refresh is needed because Hyprland does not publish a
// dedicated IPC event when an existing window is resized in place.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool monitoring: false
    property var coveredOutputs: ({})
    property bool refreshMonitorsPending: false
    // Temporary, opt-out diagnostics: log geometry metrics and both consumers.
    property bool diagnosticsEnabled: false
    property var coverageDiagnostics: ({})
    property var lastDiagnosticSignatures: ({})
    property var lastConsumerStates: ({})

    function isCovered(outputName, consumer) {
        const result = outputName !== "" && !!coveredOutputs[outputName]
        if (diagnosticsEnabled && consumer) {
            const key = consumer + "@" + outputName
            if (lastConsumerStates[key] !== result) {
                const updated = Object.assign({}, lastConsumerStates)
                updated[key] = result
                lastConsumerStates = updated
                console.info("[RoryCoverage] consumer=" + consumer + " output="
                    + outputName + " hidden=" + result)
            }
        }
        return result
    }

    function scheduleRefresh(refreshMonitors) {
        if (!monitoring) {
            coveredOutputs = ({})
            return
        }
        if (refreshMonitors)
            refreshMonitorsPending = true
        eventRefresh.restart()
    }

    function queryHyprland() {
        if (!monitoring)
            return
        Hyprland.refreshToplevels()
        if (refreshMonitorsPending) {
            Hyprland.refreshMonitors()
            refreshMonitorsPending = false
        }
        settleRefresh.restart()
    }

    function clientGeometry(window) {
        const client = window.lastIpcObject || ({})
        const at = client.at
        const size = client.size
        if (!at || !size || at.length < 2 || size.length < 2)
            return null
        const x = Number(at[0])
        const y = Number(at[1])
        const width = Number(size[0])
        const height = Number(size[1])
        if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0)
            return null
        return { x: x, y: y, width: width, height: height }
    }

    function monitorGeometry(monitor) {
        const raw = monitor.lastIpcObject || ({})
        const scale = Number(monitor.scale) > 0 ? Number(monitor.scale)
            : Number(raw.scale) > 0 ? Number(raw.scale) : 1
        const rawWidth = Number(raw.width) > 0 ? Number(raw.width) : Number(monitor.width)
        const rawHeight = Number(raw.height) > 0 ? Number(raw.height) : Number(monitor.height)
        // Hyprland monitor width/height are mode pixels, while client at/size
        // and monitor x/y are in the scaled global layout coordinate space.
        const width = Number(raw.effectiveWidth) > 0 ? Number(raw.effectiveWidth)
            : rawWidth / scale
        const height = Number(raw.effectiveHeight) > 0 ? Number(raw.effectiveHeight)
            : rawHeight / scale
        return { x: Number(monitor.x), y: Number(monitor.y), width: width,
            height: height, scale: scale, rawWidth: rawWidth, rawHeight: rawHeight,
            transform: Number(raw.transform) || 0, reserved: raw.reserved || [] }
    }

    function windowIsVisibleOnMonitor(window, monitor, bounds) {
        const client = window.lastIpcObject || ({})
        const workspace = window.workspace || null
        if (!window.monitor || window.monitor.id !== monitor.id)
            return null
        if (window.wayland && window.wayland.minimized)
            return null
        if (client.hidden === true || client.mapped === false)
            return null

        const activeWorkspace = monitor.activeWorkspace || null
        const specialWorkspace = (monitor.lastIpcObject || ({})).specialWorkspace || null
        const currentWorkspaceIds = []
        if (activeWorkspace)
            currentWorkspaceIds.push(String(activeWorkspace.id))
        if (specialWorkspace && Number(specialWorkspace.id) !== 0)
            currentWorkspaceIds.push(String(specialWorkspace.id))

        const clientWorkspaceId = workspace ? workspace.id
            : client.workspace ? client.workspace.id : null
        const pinned = client.pinned === true || Number(client.pinned) === 1
        if (!pinned && (clientWorkspaceId === null
                || !currentWorkspaceIds.includes(String(clientWorkspaceId))))
            return null

        const fullscreen = !!(window.wayland && window.wayland.fullscreen)
            || Number(client.fullscreen) > 0
            || Number(client.fullscreenClient) > 0
        const rect = clientGeometry(window)
        if (fullscreen && bounds.width > 0 && bounds.height > 0)
            return { x: bounds.x, y: bounds.y,
                width: bounds.width, height: bounds.height }
        if (!rect || bounds.width <= 0 || bounds.height <= 0)
            return null

        const left = Math.max(rect.x, bounds.x)
        const top = Math.max(rect.y, bounds.y)
        const right = Math.min(rect.x + rect.width, bounds.x + bounds.width)
        const bottom = Math.min(rect.y + rect.height, bounds.y + bounds.height)
        const overlapWidth = Math.max(0, right - left)
        const overlapHeight = Math.max(0, bottom - top)
        if (overlapWidth <= 0 || overlapHeight <= 0)
            return null
        return { x: left, y: top, width: overlapWidth, height: overlapHeight }
    }

    function boundsForRects(rects) {
        if (!rects.length)
            return null
        let left = rects[0].x
        let top = rects[0].y
        let right = rects[0].x + rects[0].width
        let bottom = rects[0].y + rects[0].height
        for (const rect of rects) {
            left = Math.min(left, rect.x)
            top = Math.min(top, rect.y)
            right = Math.max(right, rect.x + rect.width)
            bottom = Math.max(bottom, rect.y + rect.height)
        }
        return { x: left, y: top, width: right - left, height: bottom - top }
    }

    function unionArea(rects) {
        if (!rects.length)
            return 0

        const xEdges = []
        for (const rect of rects) {
            xEdges.push(rect.x, rect.x + rect.width)
        }
        xEdges.sort((a, b) => a - b)

        let area = 0
        for (let i = 0; i < xEdges.length - 1; ++i) {
            const x1 = xEdges[i]
            const x2 = xEdges[i + 1]
            const stripWidth = x2 - x1
            if (stripWidth <= 0)
                continue

            const intervals = []
            for (const rect of rects) {
                if (rect.x < x2 && rect.x + rect.width > x1)
                    intervals.push([rect.y, rect.y + rect.height])
            }
            intervals.sort((a, b) => a[0] - b[0])

            let coveredY = 0
            let start = null
            let end = null
            for (const interval of intervals) {
                if (start === null) {
                    start = interval[0]
                    end = interval[1]
                } else if (interval[0] <= end) {
                    end = Math.max(end, interval[1])
                } else {
                    coveredY += end - start
                    start = interval[0]
                    end = interval[1]
                }
            }
            if (start !== null)
                coveredY += end - start
            area += stripWidth * coveredY
        }
        return area
    }

    function updateCoverage() {
        if (!monitoring) {
            coveredOutputs = ({})
            return
        }
        const next = ({})
        const diagnostics = ({})
        const monitors = Hyprland.monitors.values || []
        const windows = Hyprland.toplevels.values || []
        for (const monitor of monitors) {
            const monitorRect = monitorGeometry(monitor)
            const monitorArea = monitorRect.width * monitorRect.height
            const occupiedRects = []
            if (monitorArea <= 0) {
                next[monitor.name] = false
                continue
            }
            const wasCovered = !!coveredOutputs[monitor.name]
            const windowDetails = []
            for (const window of windows) {
                const rect = windowIsVisibleOnMonitor(window, monitor, monitorRect)
                if (rect)
                    occupiedRects.push(rect)
                const client = window.lastIpcObject || ({})
                windowDetails.push({
                    address: window.address,
                    appId: window.wayland?.appId || client.class || client.initialClass || "",
                    monitor: window.monitor?.name || "",
                    workspace: window.workspace?.id ?? client.workspace?.id ?? null,
                    at: client.at || null,
                    size: client.size || null,
                    hidden: client.hidden === true,
                    mapped: client.mapped,
                    minimized: !!window.wayland?.minimized,
                    pinned: !!client.pinned,
                    fullscreen: !!window.wayland?.fullscreen || Number(client.fullscreen) > 0
                        || Number(client.fullscreenClient) > 0,
                    included: !!rect,
                    clippedRect: rect || null
                })
            }
            const envelope = boundsForRects(occupiedRects)
            const union = unionArea(occupiedRects)
            const outputCoverage = union / monitorArea
            const envelopeArea = envelope ? envelope.width * envelope.height : 0
            const envelopeDensity = envelopeArea > 0 ? union / envelopeArea : 0
            const horizontalSpan = envelope ? envelope.width / monitorRect.width : 0
            const verticalSpan = envelope ? envelope.height / monitorRect.height : 0

            // Track actual occupied area, full-screen reach, and density as
            // separate tests. The envelope removes known outer gaps from the
            // density calculation without letting a single half-screen tile
            // pass the monitor-span checks.
            const outputThreshold = wasCovered ? 0.86 : 0.92
            const spanThreshold = wasCovered ? 0.88 : 0.94
            const densityThreshold = wasCovered ? 0.88 : 0.94
            const covered = outputCoverage >= outputThreshold
                && horizontalSpan >= spanThreshold && verticalSpan >= spanThreshold
                && envelopeDensity >= densityThreshold
            next[monitor.name] = covered

            const monitorIpc = monitor.lastIpcObject || ({})
            const snapshot = {
                output: monitor.name,
                monitor: monitorRect,
                activeWorkspace: monitor.activeWorkspace?.id ?? null,
                specialWorkspace: monitorIpc.specialWorkspace || null,
                windows: windowDetails,
                unionArea: union,
                outputCoverage: outputCoverage,
                envelope: envelope,
                envelopeDensity: envelopeDensity,
                spanX: horizontalSpan,
                spanY: verticalSpan,
                thresholds: { output: outputThreshold, span: spanThreshold,
                    density: densityThreshold },
                hidden: covered
            }
            diagnostics[monitor.name] = snapshot
            if (diagnosticsEnabled) {
                const signature = JSON.stringify(snapshot)
                if (lastDiagnosticSignatures[monitor.name] !== signature) {
                    const updated = Object.assign({}, lastDiagnosticSignatures)
                    updated[monitor.name] = signature
                    lastDiagnosticSignatures = updated
                    console.info("[RoryCoverage] " + signature)
                }
            }
        }
        coverageDiagnostics = diagnostics
        const oldNames = Object.keys(coveredOutputs)
        const newNames = Object.keys(next)
        const stateChanged = oldNames.length !== newNames.length
            || newNames.some(name => !!coveredOutputs[name] !== !!next[name])
        if (stateChanged)
            coveredOutputs = next
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const geometryEvents = [
                "activewindow", "activewindowv2", "fullscreen", "windowresize",
                "resizewindow", "openwindow", "closewindow", "movewindow",
                "movewindowv2", "workspace", "workspacev2", "focusedmon",
                "activespecial", "activespecialv2", "monitoradded", "monitorremoved",
                "changefloatingmode", "configreloaded"
            ]
            if (geometryEvents.includes(event.name)) {
                const monitorEvents = ["workspace", "workspacev2", "focusedmon",
                    "activespecial", "activespecialv2", "monitoradded", "monitorremoved",
                    "configreloaded"]
                root.scheduleRefresh(monitorEvents.includes(event.name))
            }
        }
    }

    Timer {
        id: eventRefresh
        interval: 75
        repeat: false
        onTriggered: root.queryHyprland()
    }

    Timer {
        id: settleRefresh
        interval: 60
        repeat: false
        onTriggered: root.updateCoverage()
    }

    // Hyprland does not provide a dedicated socket2 event for in-place resize.
    // Keep one bounded refresh active for the shared clock/visualizer detector.
    Timer {
        interval: 300
        repeat: true
        running: root.monitoring
        onTriggered: root.scheduleRefresh()
    }

    onMonitoringChanged: {
        if (monitoring)
            scheduleRefresh()
        else
            coveredOutputs = ({})
    }

    Component.onCompleted: scheduleRefresh()
}
