.pragma library

// Ekrandaki sade dil: "3 durak uzakta · yaklaşık 6 dk", "az önce".

function stopsText(n) {
    if (n === undefined || n === null) return ""
    if (n <= 0) return "durakta"
    if (n === 1) return "1 durak uzakta"
    return n + " durak uzakta"
}

function minutesText(m) {
    if (m === undefined || m === null || m <= 0) return ""
    return "yaklaşık " + m + " dk"
}

/** Araç satırının özeti: "4 durak uzakta · yaklaşık 6 dk". */
function vehicleSummary(v) {
    const parts = []
    const s = stopsText(v.stopsAway)
    if (s) parts.push(s)
    const m = minutesText(v.minutesAway)
    if (m) parts.push(m)
    return parts.join(" · ")
}

/** Kısa çip metni: "3 dk", "2 durak", "durakta". */
function shortEta(v) {
    if (v.stopsAway === 0) return "durakta"
    if (v.minutesAway !== undefined && v.minutesAway !== null && v.minutesAway > 0) return v.minutesAway + " dk"
    if (v.stopsAway !== undefined && v.stopsAway !== null) return v.stopsAway + " durak"
    return ""
}

function typeName(type) {
    switch (type) {
    case 3: return "Otobüs"
    case 0: return "Tramvay"
    case 4: return "Vapur"
    case 7: return "Teleferik"
    default: return "Diğer"
    }
}


/** Date → "az önce", "3 dk önce", "14:05". */
function relative(date, now) {
    if (!date) return ""
    const diff = Math.floor((now - date) / 1000)
    if (diff < 45) return "az önce"
    if (diff < 3600) return Math.round(diff / 60) + " dk önce"
    return Qt.formatTime(date, "HH:mm")
}

function clock(date) {
    return date ? Qt.formatTime(date, "HH:mm:ss") : ""
}

/** Gün maskesi ("MTWTFss") → "Hafta içi", "Cumartesi", "Pazar" ya da gün listesi. */
function dayMaskName(days) {
    const names = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    const key = days.join(",")
    if (key === "1,2,3,4,5") return "Hafta içi"
    if (key === "6") return "Cumartesi"
    if (key === "7") return "Pazar"
    if (key === "6,7") return "Hafta sonu"
    if (key === "1,2,3,4,5,6,7") return "Her gün"
    return days.map(d => names[d - 1]).join(", ")
}

/** Bugünün ISO gün numarası (1 = Pazartesi); 04:00'ten önce önceki gün (servis günü). */
function serviceWeekday(now) {
    const d = new Date(now.getTime())
    if (d.getHours() < 4) d.setDate(d.getDate() - 1)
    const js = d.getDay()
    return js === 0 ? 7 : js
}

/** Açık/koyu metin seçimi için göreli parlaklık. */
function isDark(color) {
    return (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) < 0.5
}
