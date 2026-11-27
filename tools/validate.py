"""Structural checks for a saved .rbxlx/.rbxmx file.

usage: python tools/validate.py <file> [--classes N]

Checks: well-formed XML, <roblox version="4"> root, unique referents, every <Ref> resolves
(or is "null"), every SharedString/NetAssetRef key is defined in <SharedStrings>, no
duplicate property names or legacy/Content pairs in one <Properties>, base64 payloads decode. Prints a census of
classes, value types and a few properties worth eyeballing (part colors/sizes, scripts).
"""
import base64
import binascii
import sys
import xml.etree.ElementTree as ET
from collections import Counter


# Exceptions to the Foo/FooId/FooID -> FooContent migration naming pattern.
CONTENT_ALIASES = {
    "AudioContent": ("SoundId", "Asset"),
    "VideoContent": ("Asset",),
    "TextureContent": ("Graphic",),
    "SkyboxBackContent": ("SkyboxBk",),
    "SkyboxDownContent": ("SkyboxDn",),
    "SkyboxFrontContent": ("SkyboxFt",),
    "SkyboxLeftContent": ("SkyboxLf",),
    "SkyboxRightContent": ("SkyboxRt",),
    "HSRContent": ("HSRAssetId",),
    "TemporaryReferenceMeshContent": ("TemporaryReferenceId",),
}


def content_pairs(props):
    by_name = {p.get("name"): p for p in props}
    for modern in props:
        name = modern.get("name", "")
        if modern.tag != "Content" or not name.endswith("Content"):
            continue
        stem = name[:-7]
        for candidate in (stem, stem + "Id", stem + "ID", *CONTENT_ALIASES.get(name, ())):
            legacy = by_name.get(candidate)
            if legacy is not None and legacy.tag in ("Content", "ContentId", "int64", "string"):
                yield legacy, modern


def main(path, top_classes=15):
    items = 0
    referents = set()
    duplicate_referents = 0
    refs = []
    shared_uses = []
    shared_defs = {}
    class_counts = Counter()
    type_counts = Counter()
    prop_counts = Counter()
    duplicate_props = []
    content_conflicts = []
    bad_base64 = []
    sources = {"total": 0, "decompiled": 0, "server": 0, "empty": 0, "other": 0}
    root_tag = None
    depth = 0

    for event, elem in ET.iterparse(path, events=("start", "end")):
        if event == "start":
            depth += 1
            if depth == 1:
                root_tag = (elem.tag, elem.attrib.get("version"))
            continue
        depth -= 1
        tag = elem.tag
        if tag == "Item":
            items += 1
            ref = elem.attrib.get("referent")
            if ref in referents:
                duplicate_referents += 1
            referents.add(ref)
            class_counts[elem.attrib.get("class")] += 1
            props = elem.find("Properties")
            if props is not None:
                content_conflicts.extend((elem.get("class"), old.get("name"), new.get("name"))
                                         for old, new in content_pairs(props))
                seen = set()
                for prop in props:
                    name = prop.attrib.get("name")
                    if name in seen:
                        duplicate_props.append((elem.attrib.get("class"), name))
                    seen.add(name)
                    type_counts[prop.tag] += 1
                    prop_counts[(elem.attrib.get("class"), name)] += 1
                    if prop.tag == "Ref":
                        refs.append((prop.text or "").strip())
                    elif prop.tag in ("SharedString", "NetAssetRef"):
                        shared_uses.append((prop.text or "").strip())
                    elif prop.tag == "BinaryString" and prop.text:
                        try:
                            base64.b64decode(prop.text.strip(), validate=True)
                        except (binascii.Error, ValueError):
                            bad_base64.append((elem.attrib.get("class"), name))
                    elif prop.tag == "ProtectedString" and name == "Source":
                        text = prop.text or ""
                        sources["total"] += 1
                        if "decompiled with" in text[:200]:
                            sources["decompiled"] += 1
                        elif "server script" in text[:200]:
                            sources["server"] += 1
                        elif text.strip() == "":
                            sources["empty"] += 1
                        else:
                            sources["other"] += 1
            elem.clear()
        elif tag == "SharedString" and elem.attrib.get("md5") is not None:
            key = elem.attrib["md5"]
            payload = (elem.text or "").strip()
            try:
                shared_defs[key] = len(base64.b64decode(payload, validate=True))
            except (binascii.Error, ValueError):
                bad_base64.append(("SharedStrings", key))
                shared_defs[key] = -1

    dangling = [r for r in refs if r != "null" and r not in referents]
    missing_shared = [k for k in shared_uses if k not in shared_defs]
    unused_shared = set(shared_defs) - set(shared_uses)

    problems = []
    if root_tag != ("roblox", "4"):
        problems.append(f"root element is {root_tag}, expected roblox version 4")
    if duplicate_referents:
        problems.append(f"{duplicate_referents} duplicate referents")
    if missing_shared:
        problems.append(f"{len(missing_shared)} SharedString keys are not defined")
    if duplicate_props:
        problems.append(f"{len(duplicate_props)} duplicate properties, e.g. {duplicate_props[:3]}")
    if bad_base64:
        problems.append(f"{len(bad_base64)} invalid base64 payloads, e.g. {bad_base64[:3]}")
    if content_conflicts:
        problems.append(f"{len(content_conflicts)} legacy/Content property pairs, e.g. {content_conflicts[:3]}")

    print(f"file: {path}")
    print(f"items: {items}  referents: {len(referents)}  refs: {len(refs)}  shared strings: {len(shared_defs)} "
          f"(used {len(set(shared_uses))}, unused {len(unused_shared)})")
    print("top classes:", ", ".join(f"{c}={n}" for c, n in class_counts.most_common(top_classes)))
    print("value types:", ", ".join(f"{t}={n}" for t, n in type_counts.most_common()))
    print("scripts:", sources)
    parts = sum(n for c, n in class_counts.items() if c in ("Part", "MeshPart", "UnionOperation", "WedgePart", "TrussPart", "CornerWedgePart", "Seat", "SpawnLocation", "VehicleSeat", "IntersectOperation", "NegateOperation"))
    color = sum(n for (c, p), n in prop_counts.items() if p == "Color3uint8")
    size = sum(n for (c, p), n in prop_counts.items() if p == "size")
    cframe = sum(n for (c, p), n in prop_counts.items() if p == "CFrame")
    print(f"parts: {parts}  with Color3uint8: {color}  with size: {size}  with CFrame: {cframe}")
    unions = class_counts.get("UnionOperation", 0)
    if unions:
        mesh2 = prop_counts.get(("UnionOperation", "MeshData2"), 0)
        holder = prop_counts.get(("UnionOperation", "SolidMeshHolder"), 0)
        print(f"unions: {unions}  with MeshData2: {mesh2}  with SolidMeshHolder: {holder}")
    if dangling:
        print(f"note: {len(dangling)} Ref values point outside the file (normal for model saves; Studio loads them as nil), e.g. {dangling[:3]}")
    print("RESULT:", "OK" if not problems else "PROBLEMS")
    for p in problems:
        print("  -", p)
    return 0 if not problems else 1


if __name__ == "__main__":
    # Place names can contain emoji; a Windows console defaults to cp1252.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    n = 15
    if "--classes" in sys.argv:
        n = int(sys.argv[sys.argv.index("--classes") + 1])
    sys.exit(main(sys.argv[1], n))
