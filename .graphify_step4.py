import json
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json
from networkx.readwrite import json_graph
from pathlib import Path

# Load merged graph
graph_data = json.loads(Path('graphify-out/graph.json').read_text(encoding='utf-8'))
G = json_graph.node_link_graph(graph_data, edges='links')
print(f'Graph loaded: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges')

if G.number_of_nodes() == 0:
    print('ERROR: Graph is empty!')
    raise SystemExit(1)

# Cluster + score
communities = cluster(G)
cohesion = score_all(G, communities)
print(f'Communities: {len(communities)}')

# Analyze
gods = god_nodes(G)
surprises = surprising_connections(G, communities)
labels = {cid: 'Community ' + str(cid) for cid in communities}
questions = suggest_questions(G, communities, labels)

# Detection stub for report generation
detection = {'total_files': 741, 'total_words': 153133, 'needs_graph': True, 'warning': None, 'files': {'code': [], 'document': [], 'paper': []}}
tokens = {'input': 0, 'output': 0}

report = generate(G, communities, cohesion, labels, gods, surprises, detection, tokens, '.', suggested_questions=questions)
Path('graphify-out/GRAPH_REPORT.md').write_text(report, encoding='utf-8')
to_json(G, communities, 'graphify-out/graph.json')

analysis = {
    'communities': {str(k): v for k, v in communities.items()},
    'cohesion': {str(k): v for k, v in cohesion.items()},
    'gods': gods,
    'surprises': surprises,
    'questions': questions,
}
Path('.graphify_analysis.json').write_text(json.dumps(analysis, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Step 4 done: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities')
print(f'Top god nodes: {", ".join(str(g) for g in gods[:5])}')
