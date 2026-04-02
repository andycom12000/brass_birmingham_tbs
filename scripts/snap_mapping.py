"""
Brass Birmingham TTS Snap Point -> City Mapping
Uses graph isomorphism with slot count + adjacency constraints.
"""
import json, sys, math
sys.stdout.reconfigure(encoding='utf-8')

with open('brass_birmingham_scripted.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

snaps = data.get('SnapPoints', [])

# =====================================================
# 1. Extract and cluster building snap points
# =====================================================
building_snaps = []
for i, sp in enumerate(snaps):
    pos = sp.get('Position', {})
    rot = sp.get('Rotation', {})
    tags = sp.get('Tags', [])
    if tags: continue
    x, z = pos.get('x', 0), pos.get('z', 0)
    ry = rot.get('y', 0) if rot else 0
    rz = rot.get('z', 0) if rot else 0
    if abs(ry - 180) < 10 and abs(rz) < 10:
        if abs(x - (-17.032)) < 0.1: continue
        if abs(z - 16.382) < 0.1: continue
        if abs(z - (-16.404)) < 0.1: continue
        if abs(x - 17.039) < 0.1: continue
        if 11.5 < x < 16 and -1 < z < 6: continue
        if -16 < x < 16 and -16 < z < 16:
            building_snaps.append((i, x, z))

def cluster_pts(points, threshold=2.5):
    clusters = []
    assigned = [False] * len(points)
    for i in range(len(points)):
        if assigned[i]: continue
        cl = [points[i]]
        assigned[i] = True
        for j in range(i+1, len(points)):
            if assigned[j]: continue
            for p in cl:
                dx = points[j][1] - p[1]
                dz = points[j][2] - p[2]
                if math.sqrt(dx*dx + dz*dz) < threshold:
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
    cc.append({'id': ci, 'x': cx, 'z': cz, 'count': len(cl),
               'indices': sorted([p[0] for p in cl]),
               'points': [(p[1], p[2]) for p in sorted(cl, key=lambda x: (x[1], x[2]))]})

# =====================================================
# 2. Build observed adjacency from link snap points
# =====================================================
link_snaps = []
for i, sp in enumerate(snaps):
    pos = sp.get('Position', {})
    rot = sp.get('Rotation', {})
    tags = sp.get('Tags', [])
    if tags: continue
    rz = rot.get('z', 0) if rot else 0
    ry = rot.get('y', 0) if rot else 0
    if abs(rz - 180) < 10 and (abs(ry - 180) > 10 or abs(ry) > 10):
        x, z = pos.get('x', 0), pos.get('z', 0)
        link_snaps.append((i, x, z, ry))

obs_adj = {}
for li, lx, lz, lry in link_snaps:
    dists = []
    for c in cc:
        d = math.sqrt((lx - c['x'])**2 + (lz - c['z'])**2)
        dists.append((d, c['id']))
    dists.sort()
    c1, c2 = dists[0][1], dists[1][1]
    key = (min(c1, c2), max(c1, c2))
    obs_adj.setdefault(key, []).append(li)

obs_neighbors = {}
for (c1, c2) in obs_adj:
    obs_neighbors.setdefault(c1, set()).add(c2)
    obs_neighbors.setdefault(c2, set()).add(c1)

# =====================================================
# 3. Known game data
# =====================================================
city_slots = {
    'Birmingham': 4, 'Coventry': 2, 'Dudley': 2, 'Kidderminster': 2,
    'Wolverhampton': 2, 'Coalbrookdale': 3, 'Nuneaton': 2, 'Worcester': 2,
    'Tamworth': 2, 'Walsall': 2, 'Cannock': 2, 'Burton-on-Trent': 3,
    'Stafford': 2, 'Stoke-on-Trent': 3, 'Leek': 2, 'Stone': 2,
    'Uttoxeter': 2, 'Belper': 3, 'Derby': 3, 'Redditch': 2,
}

# Links between building cities only (merchant cities excluded)
known_edges = [
    ('Birmingham', 'Coventry'), ('Birmingham', 'Dudley'), ('Birmingham', 'Redditch'),
    ('Birmingham', 'Tamworth'), ('Birmingham', 'Walsall'), ('Birmingham', 'Wolverhampton'),
    ('Birmingham', 'Worcester'), ('Birmingham', 'Cannock'),
    ('Coventry', 'Nuneaton'),
    ('Dudley', 'Kidderminster'), ('Dudley', 'Wolverhampton'), ('Dudley', 'Walsall'),
    ('Kidderminster', 'Worcester'), ('Coalbrookdale', 'Kidderminster'),
    ('Cannock', 'Wolverhampton'), ('Coalbrookdale', 'Wolverhampton'),
    ('Cannock', 'Walsall'), ('Cannock', 'Stafford'),
    ('Burton-on-Trent', 'Tamworth'), ('Burton-on-Trent', 'Cannock'),
    ('Burton-on-Trent', 'Uttoxeter'),
    ('Nuneaton', 'Tamworth'),
    ('Stafford', 'Stone'), ('Stafford', 'Uttoxeter'),
    ('Leek', 'Stoke-on-Trent'), ('Stone', 'Stoke-on-Trent'),
    ('Leek', 'Uttoxeter'),
    ('Stone', 'Uttoxeter'),
    ('Derby', 'Uttoxeter'),
    ('Belper', 'Derby'), ('Belper', 'Leek'),
    ('Burton-on-Trent', 'Derby'),
    ('Redditch', 'Worcester'),
    ('Walsall', 'Wolverhampton'),
]

known_neighbors = {}
for a, b in known_edges:
    known_neighbors.setdefault(a, set()).add(b)
    known_neighbors.setdefault(b, set()).add(a)

# =====================================================
# 4. Constraint-based assignment
# =====================================================
# C16 = Birmingham (only 4-slot cluster)
# Now use neighborhood constraints to determine the rest.

# C16 observed neighbors: C12, C14, C15, C17, C18
# Birmingham known neighbors: Coventry, Dudley, Redditch, Tamworth, Walsall,
#                              Wolverhampton, Worcester, Cannock

# So C12, C14, C15, C17, C18 are among Birmingham's 8 neighbors.
# 3 of Birmingham's neighbors have no observed link to C16
# (links to merchant areas or rail-only links might not have snap points near C16)

# Key: C17 is 3-slot, and connects to C16(Birmingham) and C14.
# No 3-slot city is adjacent to Birmingham in the known graph!
# BUT Birmingham-Cannock is rail-only (no canal), which might mean no physical snap point.
# Wait - there IS a link snap. Links 155,156 connect C16-C17.
# C17 has 3 slots. Looking at the known graph, the ONLY 3-slot cities are:
# Coalbrookdale, Burton-on-Trent, Stoke-on-Trent, Belper, Derby
# None of these connect to Birmingham!

# WAIT: looking more carefully at link 155 (7.65, -9.16) rotY=225
# Nearest: C17(d=3.8), C16(d=4.4), C18(d=5.0)
# And link 156 (7.75, -7.48) rotY=195
# Nearest: C17(d=3.2), C16(d=3.5), C14(d=4.8)
# These links are between C17 and C16 but both are >3 units away
# and C14 is only slightly further from link 156.
# Maybe these links actually connect C17-C14 and C17-C18?

# Let me re-examine: if we say links 155,156 connect C17 to something else:
# Link 155: C17(3.8) - C16(4.4) - C18(5.0)
# Link 156: C17(3.2) - C16(3.5) - C14(4.8)
# C16 is the 2nd nearest for both. If we reassign:
# 155 -> C17-C18 (but C18 is the 3rd nearest at 5.0, not 2nd)
# Not convincing.

# Alternative theory: C17 is actually a 3-slot CITY that happens to be near Birmingham.
# On the actual board, could this work?
# C17 is at (10.99, -7.34) - far east, south area
# The nearest building cities in the SE of the board would be...
# Actually, Derby IS in the east of the board, and it has 3 slots.
# Derby connects to: Uttoxeter, Belper, Nottingham, Burton-on-Trent
# C17 observed neighbors: C14, C16
# That gives Derby degree 2 (matching if some links go off-board).
# Derby-Nottingham goes off-board (to merchant). That accounts for 1.
# But Derby also connects to Uttoxeter and Belper and Burton - those are building cities.
# This doesn't match degree 2.

# Hmm. Let me try a completely different approach.
# Use backtracking search with ALL constraints.

cities = list(city_slots.keys())
cluster_ids = [c['id'] for c in cc if c['count'] > 1]  # exclude 1-slot mystery clusters

# For the search: try to assign each city to a cluster
# Constraints:
# 1. Slot count must match
# 2. If city A-city B is a known edge, then their assigned clusters should be observed neighbors
#    (but some edges might not have snap points, so this is a soft constraint)

# Hard constraint: slot count must match
# Soft constraint: maximize the number of known edges that match observed edges

def solve():
    assignment = {}  # city -> cluster_id
    used = set()

    def backtrack(city_idx):
        if city_idx == len(cities):
            return True
        city = cities[city_idx]
        slots_needed = city_slots[city]

        for c in cc:
            cid = c['id']
            if cid in used:
                continue
            if c['count'] != slots_needed:
                continue

            # Check: for all already-assigned neighbors of this city,
            # verify the cluster adjacency exists
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

    # Sort cities by most constrained first (highest degree, unique slot count)
    cities.sort(key=lambda c: (-city_slots[c], -len(known_neighbors.get(c, set()))))

    if backtrack(0):
        return assignment
    return None

result = solve()

if result:
    print("=== SUCCESSFUL CITY -> CLUSTER MAPPING ===\n")
    for city in sorted(result, key=lambda c: result[c]):
        cid = result[city]
        c = cc[cid]
        print(f"  C{cid:2d} -> {city:20s} ({c['count']} slots) at ({c['x']:7.2f}, {c['z']:7.2f}) indices={c['indices']}")

    # Verify: check how many known edges are present in observed adjacency
    print(f"\n=== EDGE VERIFICATION ===")
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

    print(f"  Matched edges: {matched}/{len(known_edges)}")
    if unmatched:
        print(f"  Unmatched edges:")
        for a, b, ca, cb in unmatched:
            print(f"    {a} -- {b}  (C{ca} -- C{cb})")

    # Print the final snap point -> city slot mapping
    print(f"\n=== SNAP POINT -> CITY SLOT MAPPING ===")
    for city in sorted(result.keys()):
        cid = result[city]
        c = cc[cid]
        print(f"\n  {city} (cluster C{cid}):")
        for si, idx in enumerate(c['indices']):
            sp = snaps[idx]
            pos = sp['Position']
            slot_num = si + 1
            print(f"    snap[{idx:3d}] -> {city}_{slot_num}  pos=({pos['x']:8.3f}, {pos['z']:8.3f})")
else:
    print("NO VALID ASSIGNMENT FOUND - constraints too strict")
    print("Trying with relaxed constraints...")

    # Relax: allow some edges to not match
    best_assignment = None
    best_score = -1

    def solve_relaxed():
        global best_assignment, best_score
        assignment = {}
        used = set()

        def backtrack(city_idx):
            global best_assignment, best_score
            if city_idx == len(cities):
                # Score: count matched edges
                score = 0
                for a, b in known_edges:
                    ca = assignment[a]
                    cb = assignment[b]
                    edge = (min(ca, cb), max(ca, cb))
                    if edge in obs_adj:
                        score += 1
                if score > best_score:
                    best_score = score
                    best_assignment = dict(assignment)
                    print(f"  New best: score={score}/{len(known_edges)}")
                return

            city = cities[city_idx]
            slots_needed = city_slots[city]

            candidates = [c for c in cc if c['id'] not in used and c['count'] == slots_needed]

            # Score each candidate by how many already-assigned neighbor edges it matches
            def candidate_score(c):
                s = 0
                for neighbor in known_neighbors.get(city, set()):
                    if neighbor in assignment:
                        ncid = assignment[neighbor]
                        edge = (min(c['id'], ncid), max(c['id'], ncid))
                        if edge in obs_adj:
                            s += 1
                return s

            candidates.sort(key=lambda c: -candidate_score(c))

            for c in candidates:
                assignment[city] = c['id']
                used.add(c['id'])
                backtrack(city_idx + 1)
                del assignment[city]
                used.discard(c['id'])

        backtrack(0)

    solve_relaxed()

    if best_assignment:
        print(f"\n=== BEST CITY -> CLUSTER MAPPING (score={best_score}/{len(known_edges)}) ===\n")
        for city in sorted(best_assignment, key=lambda c: best_assignment[c]):
            cid = best_assignment[city]
            c = cc[cid]
            print(f"  C{cid:2d} -> {city:20s} ({c['count']} slots) at ({c['x']:7.2f}, {c['z']:7.2f}) indices={c['indices']}")

        matched = 0
        unmatched = []
        for a, b in known_edges:
            ca = best_assignment[a]
            cb = best_assignment[b]
            edge = (min(ca, cb), max(ca, cb))
            if edge in obs_adj:
                matched += 1
            else:
                unmatched.append((a, b, ca, cb))

        print(f"\n  Matched edges: {matched}/{len(known_edges)}")
        if unmatched:
            print(f"  Unmatched edges:")
            for a, b, ca, cb in unmatched:
                print(f"    {a} -- {b}  (C{ca} -- C{cb})")

        print(f"\n=== SNAP POINT -> CITY SLOT MAPPING ===")
        for city in sorted(best_assignment.keys()):
            cid = best_assignment[city]
            c = cc[cid]
            print(f"\n  {city} (cluster C{cid}):")
            for si, idx in enumerate(c['indices']):
                sp = snaps[idx]
                pos = sp['Position']
                slot_num = si + 1
                print(f"    snap[{idx:3d}] -> {city}_{slot_num}  pos=({pos['x']:8.3f}, {pos['z']:8.3f})")

# =====================================================
# 5. Summary of all snap points
# =====================================================
print("\n\n=== COMPLETE SNAP POINT SUMMARY ===")
print(f"Total snap points: {len(snaps)}")

categories = {
    'left_track (income/score)': [],
    'top_track (VP)': [],
    'bottom_track (VP)': [],
    'right_track (VP)': [],
    'coal_market': [],
    'iron_market': [],
    'link_routes': [],
    'building_slots': [],
    'merchant_tiles (M2/M3/M4)': [],
    'beer_barrels (B2/B3/B4)': [],
    'deck': [],
    'off_board_slots': [],
    'corner_asset_snaps': [],
    'other': [],
}

for i, sp in enumerate(snaps):
    pos = sp.get('Position', {})
    rot = sp.get('Rotation', {})
    tags = sp.get('Tags', [])
    x, z = pos.get('x', 0), pos.get('z', 0)
    ry = rot.get('y', 0) if rot else 0
    rz = rot.get('z', 0) if rot else 0

    if any(t.startswith('M') for t in tags):
        categories['merchant_tiles (M2/M3/M4)'].append(i)
    elif any(t.startswith('B') for t in tags):
        categories['beer_barrels (B2/B3/B4)'].append(i)
    elif 'Deck' in tags:
        categories['deck'].append(i)
    elif abs(x - (-17.032)) < 0.01:
        categories['left_track (income/score)'].append(i)
    elif abs(z - 16.382) < 0.01:
        categories['top_track (VP)'].append(i)
    elif abs(z - (-16.404)) < 0.01:
        categories['bottom_track (VP)'].append(i)
    elif abs(x - 17.039) < 0.01:
        categories['right_track (VP)'].append(i)
    elif 11.5 < x < 16 and -1.0 < z < 6.0:
        if x < 13.5:
            categories['coal_market'].append(i)
        else:
            categories['iron_market'].append(i)
    elif abs(rz - 180) < 10 and (abs(ry - 180) > 10 or abs(ry) > 10):
        categories['link_routes'].append(i)
    elif abs(ry - 180) < 10 and abs(rz) < 10 and -16 < x < 16 and -16 < z < 16:
        categories['building_slots'].append(i)
    elif abs(ry - 180) < 10 and abs(rz) < 10:
        categories['off_board_slots'].append(i)
    else:
        categories['other'].append(i)

for cat, indices in categories.items():
    print(f"  {cat}: {len(indices)} snap points")
    if cat == 'other':
        for idx in indices:
            sp = snaps[idx]
            pos = sp['Position']
            rot = sp.get('Rotation', {})
            print(f"    [{idx}] pos=({pos.get('x',0):.3f}, {pos.get('z',0):.3f}) rot=({rot.get('x',0):.1f}, {rot.get('y',0):.1f}, {rot.get('z',0):.1f})")
