.pragma library

function defaults() {
    return { version: 1, enabled: false, type: "sparks", maximum: 48,
        size: 1.8, speed: 45, sensitivity: 100, life: 1.6,
        dispersion: 35, opacity: 65, color: "#ffd5a1", useVisualizerColor: true }
}
function read(encoded) {
    const result = defaults()
    let source
    try { source = JSON.parse(encoded || "{}") } catch (_) { return result }
    if (!source || typeof source !== "object" || Array.isArray(source)) return result
    result.enabled = source.enabled === true
    if (["sparks", "dust", "orbit"].indexOf(source.type) >= 0) result.type = source.type
    result.useVisualizerColor = source.useVisualizerColor !== false
    if (typeof source.color === "string" && /^#[0-9a-fA-F]{6}$/.test(source.color)) result.color = source.color
    for (const spec of [["maximum",8,192],["size",0.5,8],["speed",0,240],
            ["sensitivity",0,250],["life",0.2,6],["dispersion",0,180],["opacity",0,100]]) {
        const value = Number(source[spec[0]])
        if (source[spec[0]] !== undefined && Number.isFinite(value))
            result[spec[0]] = Math.max(spec[1], Math.min(spec[2], value))
    }
    result.maximum = Math.round(result.maximum)
    return result
}
function create(maximum, type, seed) {
    const pool = { maximum: maximum, type: type, slots: [], groups: [[],[],[],[],[],[],[],[]],
        time: 0, energy: 0, envelope: 0, previousPeak: 0, credit: 0, cursor: 0,
        random: seed === undefined ? Math.floor(Math.random() * 4294967295) : seed }
    for (let i = 0; i < maximum; ++i)
        pool.slots.push({ alive: false, initialized: false, age: 0, phase: 0, radial: 0, tangent: 0,
            seed: 0, band: 0, x: 0, y: 0, nx: 0, ny: 0, alpha: 0 })
    return pool
}
function random(pool) {
    pool.random = (1664525 * pool.random + 1013904223) >>> 0
    return pool.random / 4294967296
}
// Arc-length table built only when the existing geometry cache changes.
function path(points) {
    const lengths = [0]
    let total = 0
    for (let i = 0; i < points.length; ++i) {
        const next = points[(i + 1) % points.length]
        total += Math.hypot(next.x - points[i].x, next.y - points[i].y)
        lengths.push(total)
    }
    return { points: points, lengths: lengths, total: total }
}
function anchor(route, particle) {
    const distance = ((particle.phase % 1 + 1) % 1) * route.total
    let lo = 0, hi = route.points.length - 1
    while (lo < hi) {
        const mid = Math.floor((lo + hi) / 2)
        if (route.lengths[mid + 1] <= distance) lo = mid + 1
        else hi = mid
    }
    const a = route.points[lo], b = route.points[(lo + 1) % route.points.length]
    const fraction = (distance - route.lengths[lo])
        / Math.max(0.000001, route.lengths[lo + 1] - route.lengths[lo])
    const nx = a.nx + (b.nx - a.nx) * fraction
    const ny = a.ny + (b.ny - a.ny) * fraction
    const length = Math.hypot(nx, ny) || 1
    particle.pathT=a.t===undefined ? particle.phase%1 : a.t+((b.t===undefined ? 1 : b.t>a.t ? b.t : 1)-a.t)*fraction
    particle.nx = nx / length; particle.ny = ny / length
    particle.x = a.x + (b.x - a.x) * fraction
    particle.y = a.y + (b.y - a.y) * fraction
}
function project(pool, route, scale) {
    if (!pool || !route || route.points.length < 2 || route.total < 0.000001) return
    for (const particle of pool.slots) {
        if (!particle.alive) continue
        anchor(route, particle)
        particle.x += (particle.nx * particle.radial - particle.ny * particle.tangent) * scale
        particle.y += (particle.ny * particle.radial + particle.nx * particle.tangent) * scale
    }
}
function spawn(pool, particle, config, initial) {
    particle.alive = true; particle.initialized = true
    particle.age = initial ? random(pool) * config.life * 0.8 : 0
    particle.phase = random(pool)
    particle.seed = random(pool)
    particle.band = random(pool) * 2 - 1
    particle.radial = 0; particle.tangent = 0; particle.alpha = 0
}
function step(pool, config, route, scale, energy, peak, dt) {
    if (!pool || !route || route.points.length < 2 || route.total < 0.000001) return
    dt = Math.max(0, Math.min(0.05, dt))
    const gain = config.sensitivity / 100
    energy = Math.max(0, Math.min(1, energy * gain))
    peak = Math.max(0, Math.min(1, peak * gain))
    const beat = Math.max(0, energy - pool.envelope)
    const hit = Math.max(0, peak - pool.previousPeak)
    pool.envelope += (energy - pool.envelope) * Math.min(1, dt * 8)
    pool.previousPeak = peak
    pool.energy = energy; pool.time += dt
    if (config.type === "sparks") {
        pool.credit = Math.min(pool.maximum, pool.credit
            + dt * pool.maximum * (energy * 0.65 + beat * 3 + hit * 1.5))
        // A bounded scan, never new particle objects during animation.
        for (let checked = 0; checked < pool.maximum && pool.credit >= 1; ++checked) {
            const particle = pool.slots[pool.cursor]
            pool.cursor = (pool.cursor + 1) % pool.maximum
            if (particle.alive) continue
            spawn(pool, particle, config, false); pool.credit -= 1
        }
        // Discard unserved bursts instead of emitting stale hits after silence.
        if (pool.credit >= 1) pool.credit %= 1
    }
    for (const particle of pool.slots) {
        if (!particle.alive && config.type !== "sparks") spawn(pool, particle, config, !particle.initialized)
        if (!particle.alive) continue
        particle.age += dt
        if (particle.age >= config.life) {
            particle.alive = false; particle.alpha = 0
            continue
        }
        if (config.type === "sparks") {
            particle.radial += config.speed * (0.5 + particle.seed) * (1 + energy * 2) * dt
            particle.tangent += config.speed * particle.band * config.dispersion / 180 * dt
        } else if (config.type === "dust") {
            particle.phase += config.speed * (0.08 + energy * 0.18) * dt / route.total
            particle.radial = particle.band * config.dispersion
                + Math.sin(pool.time * config.speed / 80 + particle.seed * Math.PI * 2) * config.dispersion * 0.15
            particle.tangent = Math.cos(pool.time * config.speed / 120 + particle.seed * 6) * config.dispersion * 0.1
        } else {
            particle.phase += config.speed * (0.5 + energy * 2) * dt / route.total
            particle.radial = particle.band * config.dispersion * 0.12
            particle.tangent = 0
        }
        const fade = Math.min(1, particle.age / 0.12, (config.life - particle.age) / Math.min(0.4, config.life / 2))
        particle.alpha = Math.max(0, fade) * (0.25 + energy * 0.75)
    }
    project(pool, route, scale)
}
function draw(ctx, pool, config, visualizerColor, scale) {
    if (!pool || config.opacity <= 0) return
    for (const group of pool.groups) group.length = 0
    for (const particle of pool.slots) {
        if (!particle.alive || particle.alpha <= 0.001) continue
        if(config.visibleRuns && !config.visibleRuns.some(span=>particle.pathT>=span.start && particle.pathT<span.end))continue
        pool.groups[Math.min(7, Math.floor(particle.alpha * 8))].push(particle)
    }
    ctx.save()
    ctx.shadowBlur = 0
    ctx.fillStyle = config.useVisualizerColor ? visualizerColor : config.color
    const size = config.size * scale * (0.8 + pool.energy * 0.3)
    for (let i = 0; i < pool.groups.length; ++i) {
        const group = pool.groups[i]
        if (!group.length) continue
        const alpha = (i + 0.5) / 8 * config.opacity / 100
        // Two batched discs give a luminous point without any blur/filter.
        for (let pass = 0; pass < 2; ++pass) {
            ctx.beginPath()
            for (const particle of group) {
                const radius = size * (0.7 + particle.seed * 0.6) * (pass === 0 ? 1.8 : 0.65)
                ctx.ellipse(particle.x - radius, particle.y - radius, radius * 2, radius * 2)
            }
            ctx.globalAlpha = alpha * (pass === 0 ? 0.18 : 1)
            ctx.fill()
        }
    }
    ctx.restore()
}
