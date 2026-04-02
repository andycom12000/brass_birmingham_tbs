import json, sys, math
sys.stdout.reconfigure(encoding='utf-8')

with open('brass_birmingham_scripted.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

snaps = data.get('SnapPoints', [])

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
    cc.append({'id': ci, 'x': cx, 'z': cz, 'count': len(cl), 'indices': [p[0] for p in cl]})

# ALL link snaps with top-3 candidates
print("=== ALL LINK SNAPS WITH TOP 3 NEAREST CLUSTERS ===")
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

for li, lx, lz, lry in sorted(link_snaps, key=lambda l: l[0]):
    dists = []
    for c in cc:
        d = math.sqrt((lx - c['x'])**2 + (lz - c['z'])**2)
        dists.append((d, c['id'], c['count']))
    dists.sort()
    top3 = [(d, cid, cnt) for d, cid, cnt in dists[:3]]
    print(f"  [{li:3d}] ({lx:7.2f},{lz:7.2f}) rY={lry:3.0f} -> " +
          " | ".join(f"C{cid:2d}({cnt}s,d={d:.1f})" for d, cid, cnt in top3))

print()

# Now do the actual city assignment using constraint propagation
# FACT: C16 is the ONLY cluster with 4 slots = Birmingham
# C16 at (4.58, -6.03), indices [216, 217, 218, 219]

# C16 connects to: C12, C14, C15, C17, C18
# Birmingham connects to: Coventry, Dudley, Redditch, Tamworth, Walsall,
#                          Wolverhampton, Worcester, Cannock(rail-only)
# Note: not all links may have snap points (rail-only links might not)

# Let me build a better adjacency. Instead of just nearest 2, let me use
# a smarter approach: a link snap connects the two clusters that are closest
# to it AND are on opposite sides (based on the link's rotation angle)

# The rotY of a link indicates its direction.
# rotY=180 means the link tile faces south (along -Z)
# rotY=90 means the link tile faces west (along -X)
# etc.
# The link connects two cities that are roughly perpendicular to the tile orientation.

# Actually, simpler approach: just check if a link is closer to 3rd nearest cluster
# by a significant margin vs 2nd nearest. If not, it might be ambiguous.

adj_edges = {}
for li, lx, lz, lry in link_snaps:
    dists = []
    for c in cc:
        d = math.sqrt((lx - c['x'])**2 + (lz - c['z'])**2)
        dists.append((d, c['id']))
    dists.sort()
    c1, c2 = dists[0][1], dists[1][1]
    key = (min(c1, c2), max(c1, c2))
    if key not in adj_edges:
        adj_edges[key] = []
    adj_edges[key].append(li)

print("=== REFINED ADJACENCY ===")
for (c1, c2), links in sorted(adj_edges.items()):
    c1i = cc[c1]
    c2i = cc[c2]
    print(f"  C{c1:2d}({c1i['count']}s,{c1i['x']:6.1f},{c1i['z']:6.1f}) -- C{c2:2d}({c2i['count']}s,{c2i['x']:6.1f},{c2i['z']:6.1f})  links={links}")

print()

# Let me try a graph isomorphism approach.
# Build the observed graph (clusters as nodes, links as edges)
# Build the known graph (cities as nodes, links as edges)
# Find the isomorphism that also satisfies slot count constraints.

# Observed graph (excluding mystery single-slot nodes C8 and C21)
obs_nodes = {}
for c in cc:
    obs_nodes[c['id']] = c['count']

obs_edges = set()
for (c1, c2) in adj_edges:
    obs_edges.add((c1, c2))

# Known graph (building cities only, exclude merchant-only)
city_slots = {
    'Birmingham': 4, 'Coventry': 2, 'Dudley': 2, 'Kidderminster': 2,
    'Wolverhampton': 2, 'Coalbrookdale': 3, 'Nuneaton': 2, 'Worcester': 2,
    'Tamworth': 2, 'Walsall': 2, 'Cannock': 2, 'Burton-on-Trent': 3,
    'Stafford': 2, 'Stoke-on-Trent': 3, 'Leek': 2, 'Stone': 2,
    'Uttoxeter': 2, 'Belper': 3, 'Derby': 3, 'Redditch': 2,
}

known_edges_list = [
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

known_adj = {}
for a, b in known_edges_list:
    known_adj.setdefault(a, set()).add(b)
    known_adj.setdefault(b, set()).add(a)

obs_adj = {}
for (c1, c2) in obs_edges:
    obs_adj.setdefault(c1, set()).add(c2)
    obs_adj.setdefault(c2, set()).add(c1)

# Print degree comparison
print("=== DEGREE + SLOT COMPARISON FOR MATCHING ===")
print(f"{'Known City':25s} {'Slots':>5} {'Deg':>4}   {'Cluster':>8} {'Slots':>5} {'Deg':>4}")
known_sorted = sorted(city_slots.keys(), key=lambda c: (-city_slots[c], -len(known_adj.get(c, set()))))
obs_sorted = sorted(obs_nodes.keys(), key=lambda c: (-obs_nodes[c], -len(obs_adj.get(c, set()))))

for i in range(max(len(known_sorted), len(obs_sorted))):
    left = ""
    right = ""
    if i < len(known_sorted):
        c = known_sorted[i]
        left = f"  {c:25s} {city_slots[c]:5d} {len(known_adj.get(c, set())):4d}"
    else:
        left = " " * 37
    if i < len(obs_sorted):
        ci = obs_sorted[i]
        right = f"  C{ci:2d}      {obs_nodes[ci]:5d} {len(obs_adj.get(ci, set())):4d}"
    print(left + "   " + right)
