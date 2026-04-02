"""
Solve the snap point cluster -> city mapping for Brass Birmingham TTS mod.
Uses constraint-based backtracking with adjacency verification.
"""
import json
import sys
import math

sys.stdout.reconfigure(encoding="utf-8")

with open("brass_birmingham_scripted.json", "r", encoding="utf-8") as f:
    data = json.load(f)

snaps = data.get("SnapPoints", [])
print(f"Total snap points: {len(snaps)}")

# =====================================================
# 1. Extract and cluster building snap points
# =====================================================
building_snaps = []
for i, sp in enumerate(snaps):
    pos = sp.get("Position", {})
    rot = sp.get("Rotation", {})
    tags = sp.get("Tags", [])
    if tags:
        continue
    x, z = pos.get("x", 0), pos.get("z", 0)
    ry = rot.get("y", 0) if rot else 0
    rz = rot.get("z", 0) if rot else 0
    if abs(ry - 180) < 10 and abs(rz) < 10:
        # Exclude edge tracks
        if abs(x - (-17.032)) < 0.1:
            continue
        if abs(z - 16.382) < 0.1:
            continue
        if abs(z - (-16.404)) < 0.1:
            continue
        if abs(x - 17.039) < 0.1:
            continue
        # Exclude market area
        if 11.5 < x < 16 and -1 < z < 6:
            continue
        if -16 < x < 16 and -16 < z < 16:
            building_snaps.append((i, x, z))

print(f"Building snap points: {len(building_snaps)}")


def cluster_pts(points, threshold=2.5):
    clusters = []
    assigned = [False] * len(points)
    for i in range(len(points)):
        if assigned[i]:
            continue
        cl = [points[i]]
        assigned[i] = True
        for j in range(i + 1, len(points)):
            if assigned[j]:
                continue
            for p in cl:
                dx = points[j][1] - p[1]
                dz = points[j][2] - p[2]
                if math.sqrt(dx * dx + dz * dz) < threshold:
                    cl.append(points[j])
                    assigned[j] = True
                    break
        clusters.append(cl)
    return clusters


clusters = cluster_pts(building_snaps)
cc = []
for ci, cl in enumerate(clusters):
    cx = sum(p[1] for p in cl) / len(cl)
    cz = sum(p[2] for p in cl) / len(cl)
    cc.append(
        {
            "id": ci,
            "x": cx,
            "z": cz,
            "count": len(cl),
            "indices": sorted([p[0] for p in cl]),
        }
    )

print(f"Clusters: {len(clusters)}")
for c in cc:
    print(
        f"  C{c['id']:2d}: {c['count']} slots at ({c['x']:7.2f}, {c['z']:7.2f}) indices={c['indices']}"
    )

# =====================================================
# 2. Build observed adjacency from link snap points
# =====================================================
link_snaps = []
for i, sp in enumerate(snaps):
    pos = sp.get("Position", {})
    rot = sp.get("Rotation", {})
    tags = sp.get("Tags", [])
    if tags:
        continue
    rz = rot.get("z", 0) if rot else 0
    ry = rot.get("y", 0) if rot else 0
    if abs(rz - 180) < 10 and (abs(ry - 180) > 10 or abs(ry) > 10):
        x, z = pos.get("x", 0), pos.get("z", 0)
        link_snaps.append((i, x, z, ry))

print(f"Link snap points: {len(link_snaps)}")

obs_adj = {}
for li, lx, lz, lry in link_snaps:
    dists = []
    for c in cc:
        d = math.sqrt((lx - c["x"]) ** 2 + (lz - c["z"]) ** 2)
        dists.append((d, c["id"]))
    dists.sort()
    c1, c2 = dists[0][1], dists[1][1]
    key = (min(c1, c2), max(c1, c2))
    obs_adj.setdefault(key, []).append(li)

obs_neighbors = {}
for c1, c2 in obs_adj:
    obs_neighbors.setdefault(c1, set()).add(c2)
    obs_neighbors.setdefault(c2, set()).add(c1)

print(f"Observed edges: {len(obs_adj)}")

# =====================================================
# 3. Known game data
# =====================================================
city_slots = {
    "Birmingham": 4,
    "Coventry": 2,
    "Dudley": 2,
    "Kidderminster": 2,
    "Wolverhampton": 2,
    "Coalbrookdale": 3,
    "Nuneaton": 2,
    "Worcester": 2,
    "Tamworth": 2,
    "Walsall": 2,
    "Cannock": 2,
    "Burton-on-Trent": 3,
    "Stafford": 2,
    "Stoke-on-Trent": 3,
    "Leek": 2,
    "Stone": 2,
    "Uttoxeter": 2,
    "Belper": 3,
    "Derby": 3,
    "Redditch": 2,
}

known_edges = [
    ("Birmingham", "Coventry"),
    ("Birmingham", "Dudley"),
    ("Birmingham", "Redditch"),
    ("Birmingham", "Tamworth"),
    ("Birmingham", "Walsall"),
    ("Birmingham", "Wolverhampton"),
    ("Birmingham", "Worcester"),
    ("Birmingham", "Cannock"),
    ("Coventry", "Nuneaton"),
    ("Dudley", "Kidderminster"),
    ("Dudley", "Wolverhampton"),
    ("Dudley", "Walsall"),
    ("Kidderminster", "Worcester"),
    ("Coalbrookdale", "Kidderminster"),
    ("Cannock", "Wolverhampton"),
    ("Coalbrookdale", "Wolverhampton"),
    ("Cannock", "Walsall"),
    ("Cannock", "Stafford"),
    ("Burton-on-Trent", "Tamworth"),
    ("Burton-on-Trent", "Cannock"),
    ("Burton-on-Trent", "Uttoxeter"),
    ("Nuneaton", "Tamworth"),
    ("Stafford", "Stone"),
    ("Stafford", "Uttoxeter"),
    ("Leek", "Stoke-on-Trent"),
    ("Stone", "Stoke-on-Trent"),
    ("Leek", "Uttoxeter"),
    ("Stone", "Uttoxeter"),
    ("Derby", "Uttoxeter"),
    ("Belper", "Derby"),
    ("Belper", "Leek"),
    ("Burton-on-Trent", "Derby"),
    ("Redditch", "Worcester"),
    ("Walsall", "Wolverhampton"),
]

known_neighbors = {}
for a, b in known_edges:
    known_neighbors.setdefault(a, set()).add(b)
    known_neighbors.setdefault(b, set()).add(a)

cities = list(city_slots.keys())

# Sort cities by most constrained first
cities.sort(
    key=lambda c: (-city_slots[c], -len(known_neighbors.get(c, set())))
)

print(f"\nSorted cities for solving: {cities}")

# =====================================================
# 4. Constraint-based solver (strict)
# =====================================================
def solve_strict():
    assignment = {}
    used = set()

    def backtrack(city_idx):
        if city_idx == len(cities):
            return True
        city = cities[city_idx]
        slots_needed = city_slots[city]

        for c in cc:
            cid = c["id"]
            if cid in used:
                continue
            if c["count"] != slots_needed:
                continue

            ok = True
            for neighbor in known_neighbors.get(city, set()):
                if neighbor in assignment:
                    ncid = assignment[neighbor]
                    edge = (min(cid, ncid), max(cid, ncid))
                    if edge not in obs_adj:
                        ok = False
                        break

            if not ok:
                continue

            assignment[city] = cid
            used.add(cid)
            if backtrack(city_idx + 1):
                return True
            del assignment[city]
            used.discard(cid)

        return False

    if backtrack(0):
        return assignment
    return None


result = solve_strict()

if not result:
    print("\nStrict solver failed, trying relaxed...")
    # Relaxed: find assignment maximizing matched edges
    best_assignment = [None]
    best_score = [-1]

    def solve_relaxed():
        assignment = {}
        used = set()

        def backtrack(city_idx):
            if city_idx == len(cities):
                score = 0
                for a, b in known_edges:
                    ca = assignment[a]
                    cb = assignment[b]
                    edge = (min(ca, cb), max(ca, cb))
                    if edge in obs_adj:
                        score += 1
                if score > best_score[0]:
                    best_score[0] = score
                    best_assignment[0] = dict(assignment)
                    print(f"  New best: score={score}/{len(known_edges)}")
                return

            city = cities[city_idx]
            slots_needed = city_slots[city]
            candidates = [
                c for c in cc if c["id"] not in used and c["count"] == slots_needed
            ]

            def candidate_score(c):
                s = 0
                for neighbor in known_neighbors.get(city, set()):
                    if neighbor in assignment:
                        ncid = assignment[neighbor]
                        edge = (min(c["id"], ncid), max(c["id"], ncid))
                        if edge in obs_adj:
                            s += 1
                return s

            candidates.sort(key=lambda c: -candidate_score(c))

            for c in candidates:
                assignment[city] = c["id"]
                used.add(c["id"])
                backtrack(city_idx + 1)
                del assignment[city]
                used.discard(c["id"])

        backtrack(0)

    solve_relaxed()
    result = best_assignment[0]
    if result:
        print(f"\nBest relaxed score: {best_score[0]}/{len(known_edges)}")

if result:
    print("\n=== CITY -> CLUSTER MAPPING ===")
    for city in sorted(result, key=lambda c: result[c]):
        cid = result[city]
        c = cc[cid]
        print(
            f"  C{cid:2d} -> {city:20s} ({c['count']} slots) at ({c['x']:7.2f}, {c['z']:7.2f}) indices={c['indices']}"
        )

    # Verify edges
    matched = 0
    unmatched = []
    for a, b in known_edges:
        ca = result[a]
        cb = result[b]
        edge = (min(ca, cb), max(ca, cb))
        if edge in obs_adj:
            matched += 1
        else:
            unmatched.append((a, b, ca, cb))

    print(f"\nMatched edges: {matched}/{len(known_edges)}")
    if unmatched:
        print("Unmatched edges:")
        for a, b, ca, cb in unmatched:
            print(f"  {a} -- {b}  (C{ca} -- C{cb})")

    # Generate the SNAP_TAGS dict
    print("\n=== SNAP_TAGS for inject_scripts.py ===")
    print("SNAP_TAGS = {")
    for city in sorted(result.keys()):
        cid = result[city]
        c = cc[cid]
        # Sort by X ascending, then Z descending
        sorted_indices = sorted(
            c["indices"],
            key=lambda idx: (
                snaps[idx]["Position"]["x"],
                -snaps[idx]["Position"]["z"],
            ),
        )
        print(f"    # {city} ({c['count']} slots) - cluster C{cid}")
        for si, idx in enumerate(sorted_indices):
            sp = snaps[idx]
            pos = sp["Position"]
            slot_num = si + 1
            print(
                f"    {idx}: \"city_{city}_{slot_num}\",  "
                f"# ({pos['x']:8.3f}, {pos['z']:8.3f})"
            )
    print("}")

    # Also generate the ID-based mapping for BoardData compatibility
    print("\n=== SNAP_TAGS using BoardData slot IDs ===")
    # Read city slot IDs from BoardData
    bd_cities = {
        "Birmingham": [
            "Birmingham_cotton_1",
            "Birmingham_manufacturer_1",
            "Birmingham_iron_1",
            "Birmingham_manufacturer_2",
        ],
        "Coventry": ["Coventry_pottery_1", "Coventry_manufacturer_1"],
        "Dudley": ["Dudley_coal_1", "Dudley_iron_1"],
        "Kidderminster": ["Kidderminster_cotton_1", "Kidderminster_cotton_2"],
        "Wolverhampton": [
            "Wolverhampton_manufacturer_1",
            "Wolverhampton_manufacturer_2",
        ],
        "Coalbrookdale": [
            "Coalbrookdale_iron_1",
            "Coalbrookdale_iron_2",
            "Coalbrookdale_brewery_1",
        ],
        "Nuneaton": ["Nuneaton_manufacturer_1", "Nuneaton_cotton_1"],
        "Worcester": ["Worcester_cotton_1", "Worcester_cotton_2"],
        "Tamworth": ["Tamworth_cotton_1", "Tamworth_coal_1"],
        "Walsall": ["Walsall_manufacturer_1", "Walsall_brewery_1"],
        "Cannock": ["Cannock_coal_1", "Cannock_manufacturer_1"],
        "Burton-on-Trent": [
            "Burton-on-Trent_brewery_1",
            "Burton-on-Trent_brewery_2",
            "Burton-on-Trent_coal_1",
        ],
        "Stafford": ["Stafford_manufacturer_1", "Stafford_pottery_1"],
        "Stoke-on-Trent": [
            "Stoke-on-Trent_cotton_1",
            "Stoke-on-Trent_manufacturer_1",
            "Stoke-on-Trent_pottery_1",
        ],
        "Leek": ["Leek_cotton_1", "Leek_manufacturer_1"],
        "Stone": ["Stone_cotton_1", "Stone_manufacturer_1"],
        "Uttoxeter": ["Uttoxeter_manufacturer_1", "Uttoxeter_brewery_1"],
        "Belper": ["Belper_cotton_1", "Belper_manufacturer_1", "Belper_pottery_1"],
        "Derby": ["Derby_cotton_1", "Derby_brewery_1", "Derby_manufacturer_1"],
        "Redditch": ["Redditch_coal_1", "Redditch_iron_1"],
    }

    print("SNAP_TAGS = {")
    for city in sorted(result.keys()):
        cid = result[city]
        c = cc[cid]
        slot_ids = bd_cities.get(city, [])
        sorted_indices = sorted(
            c["indices"],
            key=lambda idx: (
                snaps[idx]["Position"]["x"],
                -snaps[idx]["Position"]["z"],
            ),
        )
        print(f"    # {city} ({c['count']} slots) - cluster C{cid}")
        for si, idx in enumerate(sorted_indices):
            sp = snaps[idx]
            pos = sp["Position"]
            slot_id = slot_ids[si] if si < len(slot_ids) else f"{city}_{si+1}"
            print(
                f"    {idx}: \"city_{slot_id}\",  "
                f"# ({pos['x']:8.3f}, {pos['z']:8.3f})"
            )
    print("}")
else:
    print("FAILED: No valid assignment found!")
