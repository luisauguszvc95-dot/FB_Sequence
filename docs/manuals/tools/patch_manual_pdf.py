#!/usr/bin/env python3
"""Replace documentary diagram regions while preserving the rest of a PDF.

This tool changes page graphics only. It does not alter the source catalog or
create, run, or validate automation logic. PyMuPDF is the only dependency.

Usage:
    python patch_manual_pdf.py ORIGINAL.pdf SVG_DIRECTORY OUTPUT.pdf

The catalog defaults to ORIGINAL.pdf's sibling catalog.json. SVGs must retain
the exact diagram model in a JSON <metadata> element, in the form
{"case_id": "SEQ-001", "diagram": {"nodes": [...], "edges": [...]}}.
Whitespace changes in visible text are permitted; wording changes are not.
The output PDF is installed only after every preservation check succeeds.
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import tempfile
import unicodedata
import xml.etree.ElementTree as ET

import fitz


CASE_ID = re.compile(r"\b(?:SEQ|SVC)-\d{3}\b")


class PreservationError(RuntimeError):
    """A document-preservation assertion failed."""


def require(condition, message):
    if not condition:
        raise PreservationError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def normalized_text(text):
    return "".join(unicodedata.normalize("NFC", text).split())


def character_counter(text):
    return Counter(normalized_text(text))


def local_name(tag):
    return tag.rsplit("}", 1)[-1]


def canonical_graph(diagram):
    """Preserve labels, identity, roles, direction, and edge kind exactly."""
    nodes = diagram["nodes"]
    edges = diagram["edges"]
    require(len({n["id"] for n in nodes}) == len(nodes), "Duplicate node IDs")
    ids = {n["id"] for n in nodes}
    require(all(e["from"] in ids and e["to"] in ids for e in edges), "Unknown edge endpoint")
    return {
        "nodes": sorted(
            [{"id": n["id"], "label": n["label"], "role": n.get("role")} for n in nodes],
            key=lambda n: n["id"],
        ),
        "edges": sorted(
            [{"from": e["from"], "to": e["to"], "label": e.get("label", ""),
              "kind": e.get("kind", "normal")} for e in edges],
            key=lambda e: (e["from"], e["to"], e["label"], e["kind"]),
        ),
    }


def labels(diagram):
    return [n["label"] for n in diagram["nodes"]] + [e.get("label", "") for e in diagram["edges"]]


def source_model(svg_root):
    candidates = []
    for element in svg_root.iter():
        if local_name(element.tag) != "metadata":
            continue
        try:
            value = json.loads("".join(element.itertext()))
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(value, dict):
            candidates.append(value)
    for value in candidates:
        if "diagram" in value:
            return value.get("case_id", value.get("id")), value["diagram"]
        if "nodes" in value and "edges" in value:
            return value.get("case_id", value.get("id")), value
    raise PreservationError("SVG has no source diagram metadata")


def diagram_region(page):
    candidates = [d["rect"] for d in page.get_drawings()
                  if d["type"] == "f" and d["fill"] == (1.0, 1.0, 1.0)
                  and d["rect"].width > 500 and d["rect"].height > 150]
    require(len(candidates) <= 1, f"Page {page.number + 1}: ambiguous diagram region")
    return fitz.Rect(candidates[0]) if candidates else None


def page_case_id(page, region):
    text = page.get_text(clip=fitz.Rect(0, 0, page.rect.width, region.y0))
    ids = CASE_ID.findall(text)
    require(len(set(ids)) == 1, f"Page {page.number + 1}: missing or ambiguous case heading")
    return ids[0]


def all_chars(page):
    for block in page.get_text("rawdict")["blocks"]:
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                for char in span.get("chars", []):
                    yield char


def text_fingerprint(page, excluded=None):
    """Fingerprint text and positions independently of extraction order."""
    output = []
    for char in all_chars(page):
        box = fitz.Rect(char["bbox"])
        if excluded is not None and excluded.intersects(box):
            require(excluded.contains(box), f"Text crosses diagram boundary on page {page.number + 1}")
            continue
        output.append((char["c"], *(round(x, 3) for x in char["origin"]),
                       *(round(x, 3) for x in char["bbox"])))
    return sorted(output)


def clean_object(value):
    if isinstance(value, (fitz.Rect, fitz.Point, fitz.Quad)):
        return [round(float(v), 5) for v in value]
    if isinstance(value, float):
        return round(value, 5)
    if isinstance(value, (list, tuple)):
        return [clean_object(v) for v in value]
    if isinstance(value, dict):
        return {k: clean_object(v) for k, v in value.items() if k not in {"xref", "id"}}
    return value


def link_fingerprint(doc):
    return [[clean_object(link) for link in page.get_links()] for page in doc]


def toc_fingerprint(doc):
    return clean_object(doc.get_toc(simple=False))


def pixel_difference_outside(before, after, excluded):
    """Compare every 72-dpi pixel outside the patch, allowing no changes.

    A two-pixel margin avoids anti-aliasing at the replacement boundary.
    This margin does not apply to the separate exact text/link checks.
    """
    left = before.get_pixmap(matrix=fitz.Matrix(1, 1), alpha=False)
    right = after.get_pixmap(matrix=fitz.Matrix(1, 1), alpha=False)
    require((left.width, left.height, left.n) == (right.width, right.height, right.n), "Raster dimensions changed")
    a, b = left.samples, right.samples
    if a == b:
        return 0
    n, stride = left.n, left.stride
    if excluded is None:
        return sum(x != y for x, y in zip(a, b))
    x0 = max(0, math.floor(excluded.x0) - 2)
    x1 = min(left.width, math.ceil(excluded.x1) + 2)
    y0 = max(0, math.floor(excluded.y0) - 2)
    y1 = min(left.height, math.ceil(excluded.y1) + 2)
    changed = 0
    for row in range(left.height):
        base = row * stride
        segments = [(base, base + stride)] if not y0 <= row < y1 else [
            (base, base + x0 * n), (base + x1 * n, base + stride)]
        for start, end in segments:
            aa, bb = a[start:end], b[start:end]
            if aa != bb:
                changed += sum(x != y for x, y in zip(aa, bb))
    return changed


def load_svg(svg_path, case):
    raw = svg_path.read_bytes()
    root = ET.fromstring(raw)
    require(local_name(root.tag) == "svg", f"{svg_path.name}: not an SVG")
    require(not any(local_name(e.tag) in {"script", "foreignObject"} for e in root.iter()),
            f"{svg_path.name}: unsupported active SVG content")
    for element in root.iter():
        for key, value in element.attrib.items():
            if local_name(key) == "href":
                require(value.startswith("#"), f"{svg_path.name}: external SVG resource")
    case_id, model = source_model(root)
    require(case_id == case["id"], f"{svg_path.name}: metadata case ID mismatch")
    require(canonical_graph(model) == canonical_graph(case["diagram"]),
            f"{svg_path.name}: graph differs from catalog")
    visible_text = " ".join("".join(e.itertext()) for e in root.iter() if local_name(e.tag) == "text")
    expected = " ".join(labels(case["diagram"]))
    require(character_counter(visible_text) == character_counter(expected),
            f"{svg_path.name}: visible labels differ from catalog")
    with fitz.open(stream=raw, filetype="svg") as svg_doc:
        pdf_bytes = svg_doc.convert_to_pdf()
    vector_doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    require(len(vector_doc) == 1, f"{svg_path.name}: expected one vector page")
    page = vector_doc[0]
    require(character_counter(page.get_text()) == character_counter(expected),
            f"{svg_path.name}: conversion lost searchable label text")
    require(not page.get_images(), f"{svg_path.name}: replacement contains raster images")
    bounds = page.rect + (-0.1, -0.1, 0.1, 0.1)
    require(all(bounds.contains(fitz.Rect(c["bbox"])) for c in all_chars(page)),
            f"{svg_path.name}: rendered text outside viewBox")
    require(all(bounds.contains(d["rect"]) for d in page.get_drawings()),
            f"{svg_path.name}: vector outside viewBox")
    return vector_doc, {
        "svg_sha256": digest(raw),
        "source_graph_sha256": digest(json.dumps(canonical_graph(model), ensure_ascii=False, sort_keys=True).encode()),
        "node_count": len(model["nodes"]), "edge_count": len(model["edges"]),
        "metadata_matches_catalog": True, "visible_labels_preserved": True,
        "searchable_labels_preserved": True, "vector_bounds_valid": True,
    }


def patch_manual(original, svg_directory, output, catalog_path, qa_path):
    original, svg_directory, output = map(Path, (original, svg_directory, output))
    catalog_path, qa_path = Path(catalog_path), Path(qa_path)
    require(original.resolve() != output.resolve(), "Never overwrite the original PDF")
    require(not output.exists(), "Output already exists; choose a new output path")
    require(not qa_path.exists(), "QA output already exists; choose a new QA path")
    require(output.parent.exists() and qa_path.parent.exists(), "Output directories must exist")
    catalog_bytes = catalog_path.read_bytes()
    catalog = json.loads(catalog_bytes)
    cases = {c["id"]: c for c in catalog["cases"]}
    require(len(cases) == len(catalog["cases"]), "Duplicate catalog IDs")
    with fitz.open(original) as before, fitz.open(original) as working:
        require(not before.is_encrypted, "Encrypted originals are not supported")
        require(not any(page.first_annot for page in before), "Original has annotations; preservation needs manual review")
        regions, discovered, patches = {}, {}, []
        for page in before:
            region = diagram_region(page)
            if region is None:
                continue
            case_id = page_case_id(page, region)
            require(case_id not in discovered, f"Repeated case page: {case_id}")
            require(case_id in cases, f"{case_id}: case missing from catalog")
            require(page.rect.contains(region), f"{case_id}: original region outside page")
            require(not any(region.intersects(link["from"]) for link in page.get_links()),
                    f"{case_id}: diagram overlaps a link")
            regions[page.number] = region
            discovered[case_id] = page.number
        require(set(discovered) == set(cases), "Catalog/PDF case coverage mismatch")
        svg_ids = {p.stem for p in svg_directory.glob("*.svg") if CASE_ID.fullmatch(p.stem)}
        require(svg_ids == set(cases), "SVG/catalog case coverage mismatch")
        before_links, before_toc = link_fingerprint(before), toc_fingerprint(before)
        before_text = [text_fingerprint(page, regions.get(page.number)) for page in before]
        for case_id, number in discovered.items():
            region = regions[number]
            case = cases[case_id]
            expected = character_counter(" ".join(labels(case["diagram"])))
            require(character_counter(before[number].get_text(clip=region)) == expected,
                    f"{case_id}: original PDF labels differ from catalog")
            svg_path = svg_directory / f"{case_id}.svg"
            vector_doc, svg_checks = load_svg(svg_path, case)
            try:
                page = working[number]
                page.add_redact_annot(region, fill=(1, 1, 1), cross_out=False)
                page.apply_redactions(images=2, graphics=1, text=0)
                page.show_pdf_page(region, vector_doc, 0, keep_proportion=True, overlay=True)
            finally:
                vector_doc.close()
            patches.append({"case_id": case_id, "page": number + 1,
                            "region": list(region), "region_inside_page": True, **svg_checks})
        with tempfile.TemporaryDirectory(prefix="manual-patch-", dir=output.parent) as temp:
            candidate_path = Path(temp) / "candidate.pdf"
            working.save(candidate_path, garbage=4, deflate=True)
            with fitz.open(candidate_path) as after:
                require(len(before) == len(after), "Page count changed")
                require([list(p.rect) for p in before] == [list(p.rect) for p in after], "Page bounds changed")
                require(before.metadata == after.metadata, "Document metadata changed")
                require(before_links == link_fingerprint(after), "Links or their targets changed")
                require(before_toc == toc_fingerprint(after), "Bookmarks changed")
                page_checks = []
                for number, page in enumerate(after):
                    region = regions.get(number)
                    external_equal = before_text[number] == text_fingerprint(page, region)
                    require(external_equal, f"Page {number + 1}: exterior text or positions changed")
                    pixel_changes = pixel_difference_outside(before[number], page, region)
                    require(pixel_changes == 0, f"Page {number + 1}: exterior graphics changed")
                    if region is not None:
                        case_id = next(cid for cid, num in discovered.items() if num == number)
                        expected = character_counter(" ".join(labels(cases[case_id]["diagram"])))
                        require(character_counter(page.get_text(clip=region)) == expected,
                                f"{case_id}: inserted PDF labels differ from catalog")
                    page_checks.append({"page": number + 1, "external_text_and_positions_equal": True,
                                        "outside_pixel_channel_changes": pixel_changes})
                report = {
                    "schema": "documentary-diagram-preservation/1", "status": "PASS",
                    "scope": "PDF_GRAPHICS_ONLY_NO_RUNTIME_VALIDATION",
                    "original_file": original.name, "output_file": output.name,
                    "original_sha256": digest(original.read_bytes()),
                    "output_sha256": digest(candidate_path.read_bytes()),
                    "catalog_sha256": digest(catalog_bytes),
                    "page_count_before": len(before), "page_count_after": len(after),
                    "diagram_count": len(patches), "case_ids": sorted(discovered),
                    "link_count_before": sum(map(len, before_links)),
                    "link_count_after": sum(map(len, link_fingerprint(after))),
                    "bookmark_count_before": len(before_toc), "bookmark_count_after": len(toc_fingerprint(after)),
                    "links_equal": True, "bookmarks_equal": True, "document_metadata_equal": True,
                    "outside_text_equal": True, "outside_graphics_equal_at_72dpi": True,
                    "catalog_graphs_preserved": True, "all_visible_labels_preserved": True,
                    "all_diagram_regions_inside_pages": True,
                    "patches": patches, "pages": page_checks,
                    "limitations": [
                        "Topology preservation compares catalog and SVG source metadata; visual routing needs review.",
                        "Pixel comparison excludes a two-pixel margin around each diagram; exterior text is checked exactly.",
                        "No control code, simulation, native build, machine operation, or integration test is executed.",
                    ],
                }
            candidate_path.replace(output)
            qa_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("original", type=Path)
    parser.add_argument("svg_directory", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--qa", type=Path)
    args = parser.parse_args()
    report = patch_manual(args.original, args.svg_directory, args.output,
                          args.catalog or args.original.with_name("catalog.json"),
                          args.qa or args.output.with_suffix(".qa.json"))
    print(json.dumps({k: report[k] for k in ("status", "diagram_count", "page_count_after",
                                            "link_count_after", "bookmark_count_after")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
