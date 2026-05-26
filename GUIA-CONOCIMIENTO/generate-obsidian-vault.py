#!/usr/bin/env python3
"""
generate-obsidian-vault.py
Genera un vault de Obsidian desde graphify-out/graph.json.

Uso:
  python scripts/generate-obsidian-vault.py
  python scripts/generate-obsidian-vault.py --graph graphify-out/graph.json --vault ../MI_VAULT
"""

import json
import re
import argparse
from pathlib import Path
from collections import defaultdict

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def safe_filename(label: str) -> str:
    """Convierte un label a nombre de archivo válido para Obsidian."""
    name = re.sub(r'[\\/:*?"<>|]', '_', label)
    return name[:120]  # Obsidian soporta nombres largos pero acotamos


def wikilink(label: str) -> str:
    return f"[[{label}]]"


# ─────────────────────────────────────────────
# Generador principal
# ─────────────────────────────────────────────

def generate_vault(graph_path: str, vault_path: str):
    graph_file = Path(graph_path)
    vault = Path(vault_path)

    if not graph_file.exists():
        print(f"ERROR: No se encuentra {graph_file}")
        return

    print(f"Leyendo {graph_file}...")
    with open(graph_file, encoding="utf-8") as f:
        g = json.load(f)

    nodes = g.get("nodes", [])
    links = g.get("links", [])

    # Índices
    id_to_node = {n["id"]: n for n in nodes}
    community_nodes: dict[int, list] = defaultdict(list)
    outgoing: dict[str, list] = defaultdict(list)   # id → [(relation, target_id)]
    incoming: dict[str, list] = defaultdict(list)   # id → [(relation, source_id)]

    for n in nodes:
        community_nodes[n.get("community", -1)].append(n)

    for link in links:
        src, tgt, rel = link.get("source"), link.get("target"), link.get("relation", "relates")
        outgoing[src].append((rel, tgt))
        incoming[tgt].append((rel, src))

    # Crear carpetas
    vault.mkdir(parents=True, exist_ok=True)
    (vault / "comunidades").mkdir(exist_ok=True)
    (vault / "simbolos").mkdir(exist_ok=True)

    total_nodes = len(nodes)
    total_communities = len(community_nodes)
    print(f"  {total_nodes} nodos · {len(links)} edges · {total_communities} comunidades")

    # ── Generar nota por nodo ──────────────────────────────────
    print("Generando notas de símbolos...")
    for i, node in enumerate(nodes):
        label = node["label"]
        nid = node["id"]
        community = node.get("community", -1)
        source_file = node.get("source_file", "")
        source_loc = node.get("source_location", "")
        file_type = node.get("file_type", "")

        out_links = outgoing.get(nid, [])
        in_links = incoming.get(nid, [])

        lines = [
            f"# {label}",
            "",
            "## Metadatos",
            f"- **Tipo:** `{file_type}`",
            f"- **Archivo:** `{source_file}` `{source_loc}`",
            f"- **Comunidad:** [[comunidades/Comunidad {community}]]",
            "",
        ]

        if out_links:
            lines += ["## Depende de", ""]
            for rel, tid in out_links[:40]:
                tnode = id_to_node.get(tid)
                tlabel = tnode["label"] if tnode else tid
                lines.append(f"- `{rel}` → [[simbolos/{safe_filename(tlabel)}|{tlabel}]]")
            if len(out_links) > 40:
                lines.append(f"- _(y {len(out_links) - 40} más...)_")
            lines.append("")

        if in_links:
            lines += ["## Usado por", ""]
            for rel, sid in in_links[:40]:
                snode = id_to_node.get(sid)
                slabel = snode["label"] if snode else sid
                lines.append(f"- `{rel}` → [[simbolos/{safe_filename(slabel)}|{slabel}]]")
            if len(in_links) > 40:
                lines.append(f"- _(y {len(in_links) - 40} más...)_")
            lines.append("")

        note_path = vault / "simbolos" / f"{safe_filename(label)}.md"
        note_path.write_text("\n".join(lines), encoding="utf-8")

        if (i + 1) % 500 == 0:
            print(f"  {i + 1}/{total_nodes}...")

    # ── Generar nota por comunidad ─────────────────────────────
    print("Generando notas de comunidades...")
    for comm_id, comm_nodes in sorted(community_nodes.items()):
        # Ordenar por conectividad (nodos con más edges primero)
        def connectivity(n):
            nid = n["id"]
            return len(outgoing.get(nid, [])) + len(incoming.get(nid, []))

        comm_nodes_sorted = sorted(comm_nodes, key=connectivity, reverse=True)
        top_nodes = comm_nodes_sorted[:5]

        lines = [
            f"# Comunidad {comm_id}",
            "",
            f"**{len(comm_nodes)} nodos**",
            "",
            "## Nodos principales",
            "",
        ]

        for n in top_nodes:
            deg = connectivity(n)
            lines.append(f"- [[simbolos/{safe_filename(n['label'])}|{n['label']}]] — {deg} conexiones")

        lines += ["", "## Todos los nodos", ""]
        for n in comm_nodes_sorted:
            lines.append(f"- [[simbolos/{safe_filename(n['label'])}|{n['label']}]]")

        note_path = vault / "comunidades" / f"Comunidad {comm_id}.md"
        note_path.write_text("\n".join(lines), encoding="utf-8")

    # ── Generar índice principal ───────────────────────────────
    print("Generando índice principal...")

    # Top 10 nodos dios (más conectados)
    all_nodes_by_degree = sorted(
        nodes,
        key=lambda n: len(outgoing.get(n["id"], [])) + len(incoming.get(n["id"], [])),
        reverse=True
    )
    god_nodes = all_nodes_by_degree[:10]

    index_lines = [
        "# Knowledge Graph — Índice",
        "",
        f"> {total_nodes} nodos · {len(links)} edges · {total_communities} comunidades",
        "",
        "## Nodos Dios (más conectados)",
        "",
    ]
    for n in god_nodes:
        deg = len(outgoing.get(n["id"], [])) + len(incoming.get(n["id"], []))
        index_lines.append(
            f"- [[simbolos/{safe_filename(n['label'])}|{n['label']}]] — {deg} conexiones"
        )

    index_lines += [
        "",
        "## Comunidades",
        "",
    ]
    for comm_id in sorted(community_nodes.keys())[:50]:
        count = len(community_nodes[comm_id])
        index_lines.append(f"- [[comunidades/Comunidad {comm_id}]] — {count} nodos")
    if total_communities > 50:
        index_lines.append(f"- _(y {total_communities - 50} comunidades más en la carpeta `/comunidades/`)_")

    (vault / "INDEX.md").write_text("\n".join(index_lines), encoding="utf-8")

    print(f"\n✓ Vault generado en: {vault.resolve()}")
    print(f"  {total_nodes} notas de símbolos")
    print(f"  {total_communities} notas de comunidades")
    print(f"  1 INDEX.md")
    print("\nAbre la carpeta como vault en Obsidian para explorar el grafo.")


# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Genera vault Obsidian desde graph.json")
    parser.add_argument("--graph", default="graphify-out/graph.json", help="Ruta a graph.json")
    parser.add_argument("--vault", default="../SEIS_VAULT", help="Carpeta destino del vault")
    args = parser.parse_args()

    generate_vault(args.graph, args.vault)
