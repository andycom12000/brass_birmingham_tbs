"""
Build the SNAP_TAGS mapping for inject_scripts.py.
Uses geographic position matching between board snap point clusters
and known city locations on the Brass Birmingham map.

Outputs a Python dict literal ready to paste into inject_scripts.py.
"""
import json
import sys
import math

sys.stdout.reconfigure(encoding="utf-8")

with open("brass_birmingham_scripted.json", "r", encoding="utf-8") as f:
    data = json.load(f)

snaps = data["SnapPoints"]

# ── 1. Extract building-slot snap points ──────────────────────
building = []
for i, sp in enumerate(snaps):
    pos = sp.get("Position", {})
    rot = sp.get("Rotation", {})
    tags = sp.get("Tags", [])
    if tags:
        continue
    x, z = pos.get("x", 0), pos.get("z", 0)
    ry = rot.get("y", 0) if rot else 0
    rz = rot.get("z", 0) if rot else 0
    # Building slots: rotY~180, rotZ~0, inside board area, not on edge tracks or market
    if abs(ry - 180) < 10 and abs(rz) < 10:
        if abs(x - (-17.032)) < 0.1: continue
        if abs(z - 16.382) < 0.1: continue
        if abs(z - (-16.404)) < 0.1: continue
        if abs(x - 17.039) < 0.1: continue
        if 11.5 < x < 16 and -1 < z < 6: continue  # market area
        if -16 < x < 16 and -16 < z < 16:
            building.append((i, x, z))

print(f"Building snap points found: {len(building)}")

# ── 2. Cluster by proximity ──────────────────────────────────
def cluster_points(points, threshold=2.8):
    """Simple agglomerative clustering."""
    clusters = []
    used = set()
    for idx_a, (i_a, xa, za) in enumerate(points):
        if idx_a in used:
            continue
        group = [(i_a, xa, za)]
        used.add(idx_a)
        # Keep expanding: check all points against any in the group
        changed = True
        while changed:
            changed = False
            for idx_b, (i_b, xb, zb) in enumerate(points):
                if idx_b in used:
                    continue
                for (_, gx, gz) in group:
                    if math.sqrt((xb - gx)**2 + (zb - gz)**2) < threshold:
                        group.append((i_b, xb, zb))
                        used.add(idx_b)
                        changed = True
                        break
        clusters.append(group)
    return clusters

clusters = cluster_points(building, threshold=2.8)

# Sort clusters for display
for c in clusters:
    c.sort(key=lambda p: (p[1], -p[2]))  # sort by X asc, Z desc

clusters.sort(key=lambda c: (-len(c), sum(p[1] for p in c) / len(c)))

print(f"\nClusters found: {len(clusters)}")
for ci, c in enumerate(clusters):
    cx = sum(p[1] for p in c) / len(c)
    cz = sum(p[2] for p in c) / len(c)
    indices = [p[0] for p in c]
    print(f"  Cluster {ci:2d}: {len(c)} slots at ({cx:7.2f}, {cz:7.2f}) indices={indices}")

# ── 3. Known cities from BoardData ────────────────────────────
# Position estimates based on Brass Birmingham board geography
# Format: (city_name, slot_count, approx_x, approx_z)
CITIES = [
    ("Birmingham",       4,   4.5,  -6.0),
    ("Coalbrookdale",    3,  -9.4,  -2.3),
    ("Stoke-on-Trent",   3,  -3.0,  12.5),
    ("Burton-on-Trent",  3,  11.0,  -7.3),
    ("Derby",            3,   9.2,   8.7),
    ("Belper",           3,   8.9,  13.9),
    ("Wolverhampton",    2,  -4.5,  -1.3),
    ("Dudley",           2,  -5.4,  -9.0),
    ("Kidderminster",    2,  -2.9,  -5.5),
    ("Cannock",          2,  -0.9,   1.8),
    ("Walsall",          2,   1.1,  -2.1),
    ("Tamworth",         2,   2.4,   9.0),
    ("Nuneaton",         2,   6.5,   4.2),
    ("Worcester",        2,   7.0,   0.0),
    ("Coventry",         2,   2.9, -10.8),
    ("Stone",            2,  -3.5,   5.2),
    ("Leek",             2,  -6.7,   8.4),
    ("Stafford",         2,   1.9,  14.4),
    ("Uttoxeter",        2,  10.2,  -3.4),
    ("Redditch",         2,  -4.9, -13.4),
]

# Slot IDs for each city (from BoardData, in order)
CITY_SLOTS = {
    "Birmingham":       ["Birmingham_1", "Birmingham_2", "Birmingham_3", "Birmingham_4"],
    "Coalbrookdale":    ["Coalbrookdale_1", "Coalbrookdale_2", "Coalbrookdale_3"],
    "Stoke-on-Trent":   ["Stoke-on-Trent_1", "Stoke-on-Trent_2", "Stoke-on-Trent_3"],
    "Burton-on-Trent":  ["Burton-on-Trent_1", "Burton-on-Trent_2", "Burton-on-Trent_3"],
    "Derby":            ["Derby_1", "Derby_2", "Derby_3"],
    "Belper":           ["Belper_1", "Belper_2", "Belper_3"],
    "Wolverhampton":    ["Wolverhampton_1", "Wolverhampton_2"],
    "Dudley":           ["Dudley_1", "Dudley_2"],
    "Kidderminster":    ["Kidderminster_1", "Kidderminster_2"],
    "Cannock":          ["Cannock_1", "Cannock_2"],
    "Walsall":          ["Walsall_1", "Walsall_2"],
    "Tamworth":         ["Tamworth_1", "Tamworth_2"],
    "Nuneaton":         ["Nuneaton_1", "Nuneaton_2"],
    "Worcester":        ["Worcester_1", "Worcester_2"],
    "Coventry":         ["Coventry_1", "Coventry_2"],
    "Stone":            ["Stone_1", "Stone_2"],
    "Leek":             ["Leek_1", "Leek_2"],
    "Stafford":         ["Stafford_1", "Stafford_2"],
    "Uttoxeter":        ["Uttoxeter_1", "Uttoxeter_2"],
    "Redditch":         ["Redditch_1", "Redditch_2"],
}

# ── 4. Match clusters to cities (greedy nearest with slot count) ──

def cluster_center(c):
    return (sum(p[1] for p in c) / len(c), sum(p[2] for p in c) / len(c))

used_clusters = set()
city_to_cluster = {}

# Match by slot count + nearest position
for city, slots, cx, cz in sorted(CITIES, key=lambda c: -c[1]):
    # Find nearest cluster with matching slot count
    best_ci = None
    best_dist = float("inf")
    for ci, cluster in enumerate(clusters):
        if ci in used_clusters:
            continue
        if len(cluster) != slots:
            continue
        ccx, ccz = cluster_center(cluster)
        dist = math.sqrt((ccx - cx)**2 + (ccz - cz)**2)
        if dist < best_dist:
            best_dist = dist
            best_ci = ci
    if best_ci is not None:
        city_to_cluster[city] = best_ci
        used_clusters.add(best_ci)
        ccx, ccz = cluster_center(clusters[best_ci])
        print(f"  {city:20s} ({slots}s) -> Cluster {best_ci:2d} at ({ccx:7.2f},{ccz:7.2f}) dist={best_dist:.2f}")
    else:
        print(f"  {city:20s} ({slots}s) -> NO MATCH!")

# ── 5. Output SNAP_TAGS ──────────────────────────────────────

print("\n# === SNAP_TAGS for inject_scripts.py ===")
print("SNAP_TAGS = {")
for city in sorted(city_to_cluster.keys()):
    ci = city_to_cluster[city]
    cluster = clusters[ci]
    slot_ids = CITY_SLOTS[city]
    # Sort snap points within cluster: left-to-right (X asc), top-to-bottom (Z desc)
    sorted_pts = sorted(cluster, key=lambda p: (p[1], -p[2]))
    print(f"    # {city} ({len(cluster)} slots)")
    for si, (snap_idx, sx, sz) in enumerate(sorted_pts):
        slot_id = slot_ids[si] if si < len(slot_ids) else f"{city}_{si+1}"
        print(f'    {snap_idx}: "city_{slot_id}",  # ({sx:8.3f}, {sz:8.3f})')
print("}")

# ── 6. Report unmatched ──────────────────────────────────────
unmatched = [ci for ci in range(len(clusters)) if ci not in used_clusters]
if unmatched:
    print(f"\nUnmatched clusters: {unmatched}")
    for ci in unmatched:
        c = clusters[ci]
        ccx, ccz = cluster_center(c)
        indices = [p[0] for p in c]
        print(f"  Cluster {ci}: {len(c)} slots at ({ccx:.2f}, {ccz:.2f}) indices={indices}")
