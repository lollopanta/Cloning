"""Write a repaired copy of an XML save; never overwrite the original."""
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

from validate import content_pairs, main as validate


def repair(path):
    path = Path(path)
    output = path.with_name(path.stem + " - fixed" + path.suffix)
    if output.exists():
        raise FileExistsError(output)
    tree = ET.parse(path)
    removed = 0
    for item in tree.iter("Item"):
        props = item.find("Properties")
        if props is None:
            continue
        for legacy, modern in list(content_pairs(props)):
            props.remove(legacy)
            removed += 1
    with output.open("xb") as target:
        tree.write(target, encoding="utf-8", xml_declaration=True)
    print(f"Removed {removed} legacy properties; original unchanged.")
    return output


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(validate(repair(sys.argv[1])))
