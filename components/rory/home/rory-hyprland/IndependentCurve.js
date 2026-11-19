.pragma library
.import "FreeWave.js" as FreeWave

function hasAdvancedWave(shapeData){return FreeWave.valid(parseObject(shapeData).wave)}

function controlCount(shape, shapeData) {
    if(shape === "wave" && shapeData){const stored=parseObject(shapeData).wave;if(FreeWave.valid(stored))return stored.points.length/2}
    if (shape === "square") return 4
    if (shape === "triangle") return 3
    if (shape === "star") return 10
    if (shape === "wave") return 16
    return 8
}

function isSmoothShape(shape) {
    return shape === "circle" || shape === "ellipse" || shape === "wave"
}

function parseObject(encoded) {
    try {
        const value = JSON.parse(encoded || "{}")
        return value && typeof value === "object" && !Array.isArray(value) ? value : ({})
    } catch (error) {
        return ({})
    }
}

function validVertices(values, shape) {
    if(shape === "wave" && !Array.isArray(values))return FreeWave.valid(values)
    const count = controlCount(shape)
    return Array.isArray(values) && values.length === count * 2
        && values.every(value => Number.isFinite(Number(value)))
}

function basePolygonPoints(shape) {
    if (shape === "square") return [-1, -1, 1, -1, 1, 1, -1, 1]
    if (shape === "triangle") return [0, -1, Math.sqrt(3) / 2, 0.5, -Math.sqrt(3) / 2, 0.5]
    if (shape === "star") {
        const points = []
        for (let i = 0; i < 10; ++i) {
            const angle = -Math.PI / 2 + i * Math.PI / 5
            const radius = i % 2 === 0 ? 1 : 0.43
            points.push(radius * Math.cos(angle), radius * Math.sin(angle))
        }
        return points
    }
    return []
}

function basePoint(shape, angle) {
    if (shape === "wave") {
        const radius = 0.84 + 0.12 * Math.sin(3 * angle + 0.35)
            + 0.055 * Math.sin(7 * angle - 0.8)
        const radiusDerivative = 0.36 * Math.cos(3 * angle + 0.35)
            + 0.385 * Math.cos(7 * angle - 0.8)
        return {
            x: radius * Math.cos(angle),
            y: radius * Math.sin(angle),
            dx: radiusDerivative * Math.cos(angle) - radius * Math.sin(angle),
            dy: radiusDerivative * Math.sin(angle) + radius * Math.cos(angle)
        }
    }
    return { x: Math.cos(angle), y: Math.sin(angle), dx: -Math.sin(angle), dy: Math.cos(angle) }
}

function defaultVertices(shape) {
    if (shape === "square" || shape === "triangle" || shape === "star")
        return basePolygonPoints(shape)
    const count = controlCount(shape)
    const points = []
    for (let i = 0; i < count; ++i) {
        const angle = -3 * Math.PI / 4 + i * 2 * Math.PI / count
        const point = basePoint(shape, angle)
        points.push(point.x, point.y)
    }
    return points
}

function hasStoredVertices(shapeData, shape, legacyVertices) {
    const stored = parseObject(shapeData)[shape]
    if (validVertices(stored, shape)) return true
    return shape === "ellipse" && validVertices(parseArray(legacyVertices), shape)
}

function parseArray(encoded) {
    try {
        const value = JSON.parse(encoded || "[]")
        return Array.isArray(value) ? value : []
    } catch (error) {
        return []
    }
}

function readVertices(shapeData, shape, legacyVertices) {
    const stored = parseObject(shapeData)[shape]
    if(shape === "wave" && FreeWave.valid(stored)){const points=stored.points.slice();points.wavePath=stored;return points}
    if (validVertices(stored, shape)) return stored.map(Number)
    const legacy = parseArray(legacyVertices)
    if (shape === "ellipse" && validVertices(legacy, shape)) return legacy.map(Number)
    return defaultVertices(shape)
}

function writeVertices(shapeData, shape, values) {
    const all = parseObject(shapeData)
    if(shape === "wave" && FreeWave.valid(all.wave)){all.wave.points=values.map(Number)}
    else all[shape] = values.map(Number)
    return JSON.stringify(all)
}

function pointOnEdge(shape, edge, fraction, values, radiusX, radiusY,
                     centerX, centerY, orientationDegrees) {
    const count = shape === "wave" ? values.length/2 : controlCount(shape)
    const i = ((edge % count) + count) % count
    const next = (i + 1) % count
    const t = Math.max(0, Math.min(1, fraction))
    let localX, localY, tangentLocalX, tangentLocalY

    if(shape === "wave" && values.wavePath){
        const p=FreeWave.sample(values.wavePath,i,t)
        localX=radiusX*p.x;localY=radiusY*p.y;tangentLocalX=radiusX*p.dx;tangentLocalY=radiusY*p.dy
    } else if (isSmoothShape(shape)) {
        const step = 2 * Math.PI / count
        const startAngle = -3 * Math.PI / 4 + i * step
        const angle = startAngle + t * step
        const nextAngle = startAngle + step
        const base0 = basePoint(shape, startAngle)
        const base1 = basePoint(shape, nextAngle)
        const base = basePoint(shape, angle)
        const d0x = values[2 * i] - base0.x
        const d0y = values[2 * i + 1] - base0.y
        const d1x = values[2 * next] - base1.x
        const d1y = values[2 * next + 1] - base1.y
        const smooth = t * t * (3 - 2 * t)
        const displacementDerivative = 6 * t * (1 - t) / step
        localX = radiusX * (base.x + d0x + (d1x - d0x) * smooth)
        localY = radiusY * (base.y + d0y + (d1y - d0y) * smooth)
        tangentLocalX = radiusX * (base.dx + (d1x - d0x) * displacementDerivative)
        tangentLocalY = radiusY * (base.dy + (d1y - d0y) * displacementDerivative)
    } else {
        const ax = Number(values[2 * i]), ay = Number(values[2 * i + 1])
        const bx = Number(values[2 * next]), by = Number(values[2 * next + 1])
        localX = radiusX * (ax + (bx - ax) * t)
        localY = radiusY * (ay + (by - ay) * t)
        tangentLocalX = radiusX * (bx - ax)
        tangentLocalY = radiusY * (by - ay)
    }

    const rotation = orientationDegrees * Math.PI / 180
    const cos = Math.cos(rotation), sin = Math.sin(rotation)
    const tangentX = tangentLocalX * cos - tangentLocalY * sin
    const tangentY = tangentLocalX * sin + tangentLocalY * cos
    let normalX = tangentY
    let normalY = -tangentX

    if (!isSmoothShape(shape)) {
        let area = 0
        for (let p = 0; p < count; ++p) {
            const q = (p + 1) % count
            area += Number(values[2 * p]) * Number(values[2 * q + 1])
                - Number(values[2 * q]) * Number(values[2 * p + 1])
        }
        if (area < 0) { normalX = -normalX; normalY = -normalY }
    }
    const normalLength = Math.hypot(normalX, normalY) || 1
    return {
        x: centerX + localX * cos - localY * sin,
        y: centerY + localX * sin + localY * cos,
        nx: normalX / normalLength,
        ny: normalY / normalLength
    }
}

function controlPoint(shape, index, values, radiusX, radiusY,
                      centerX, centerY, orientationDegrees) {
    return pointOnEdge(shape, index, 0, values, radiusX, radiusY,
                       centerX, centerY, orientationDegrees)
}

function barGeometry(index, count, shape, values, radiusX, radiusY,
                     centerX, centerY, orientationDegrees) {
    const controls = shape === "wave" ? values.length/2 : controlCount(shape)
    if (isSmoothShape(shape)) {
        const position = index * controls / count
        const edge = Math.min(controls - 1, Math.floor(position))
        return pointOnEdge(shape, edge, position - edge, values, radiusX, radiusY,
                           centerX, centerY, orientationDegrees)
    }

    let perimeter = 0
    const lengths = []
    for (let i = 0; i < controls; ++i) {
        const n = (i + 1) % controls
        const length = Math.hypot((values[2 * n] - values[2 * i]) * radiusX,
                                  (values[2 * n + 1] - values[2 * i + 1]) * radiusY)
        lengths.push(length); perimeter += length
    }
    let distance = (index + 0.5) / count * perimeter
    for (let i = 0; i < controls; ++i) {
        if (distance <= lengths[i] || i === controls - 1) {
            const fraction = lengths[i] > 0 ? Math.min(1, distance / lengths[i]) : 0
            return pointOnEdge(shape, i, fraction, values, radiusX, radiusY,
                               centerX, centerY, orientationDegrees)
        }
        distance -= lengths[i]
    }
    return pointOnEdge(shape, 0, 0, values, radiusX, radiusY,
                       centerX, centerY, orientationDegrees)
}
