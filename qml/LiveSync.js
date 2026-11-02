.pragma library

// Canlı listeleri (araçlar, duraklar) kimliğe göre yerinde günceller: ListModel'e
// ekler / siler / taşır, değişen satırın yalnızca `json` alanını yazar. Böylece
// Repeater / MapItemView delegeleri her yanıtta yeniden kurulmaz (hover, ipucu, animasyon sürer).
// Satır: { key, json }. Delegede nesne: JSON.parse(model.json).

/** Aynı kimlik iki kez gelirse ikincisine sonek eklenir (kimlikler tekil kalsın). */
function uniqueKeys(items, keyFn) {
    const seen = {}
    return items.map((it, i) => {
        let k = String(keyFn(it, i))
        if (seen[k] !== undefined) k += "#" + (++seen[k])
        else seen[k] = 0
        return k
    })
}

function sync(model, items, keyFn) {
    const keys = uniqueKeys(items, keyFn)
    const json = items.map(it => JSON.stringify(it))
    const want = {}
    for (const k of keys) want[k] = true
    // Giden satırlar (sondan başa).
    for (let i = model.count - 1; i >= 0; --i)
        if (!want[model.get(i).key]) model.remove(i)
    for (let i = 0; i < keys.length; ++i) {
        if (i < model.count && model.get(i).key === keys[i]) {
            if (model.get(i).json !== json[i]) model.setProperty(i, "json", json[i])
            continue
        }
        let from = -1
        for (let j = i + 1; j < model.count; ++j)
            if (model.get(j).key === keys[i]) { from = j; break }
        if (from >= 0) {
            model.move(from, i, 1)
            if (model.get(i).json !== json[i]) model.setProperty(i, "json", json[i])
        } else {
            model.insert(i, { key: keys[i], json: json[i] })
        }
    }
}

/** Araç kimliği: vehicleId, yoksa plaka, yoksa sıra. */
function vehicleKey(v, i) {
    if (v.vehicleId !== undefined && v.vehicleId !== null && v.vehicleId !== "") return "v" + v.vehicleId
    if (v.plate) return "p" + v.plate
    return "i" + i
}

function stopKey(s) { return "s" + s.id }
