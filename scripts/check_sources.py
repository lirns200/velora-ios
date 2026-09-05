"""Optional Windows source checks. This is not a Swift compiler or iOS build.

python -m pip install --target .build-tools tree-sitter tree-sitter-swift PyYAML Pillow
python scripts/check_sources.py
"""
import json
import pathlib
import plistlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".build-tools"))
import yaml
from PIL import Image
from tree_sitter import Language, Parser
import tree_sitter_swift


def check():
    parser = Parser(Language(tree_sitter_swift.language()))
    swift = []
    for folder in ("App", "Tunnel", "Shared", "Packages"):
        swift += [p for p in (ROOT / folder).rglob("*.swift") if ".build" not in p.parts]
    failed = []
    for path in swift:
        tree = parser.parse(path.read_bytes())
        if tree.root_node.has_error:
            failed.append(path.relative_to(ROOT).as_posix())
    if failed:
        raise ValueError("Swift syntax parser errors: " + ", ".join(failed))
    for folder in ("App", "Tunnel"):
        for path in (ROOT / folder).rglob("*"):
            if path.suffix in (".plist", ".entitlements"):
                plistlib.loads(path.read_bytes())
            elif path.suffix == ".json":
                json.loads(path.read_bytes())
    project = yaml.safe_load((ROOT / "project.yml").read_text())
    workflow = yaml.safe_load((ROOT / ".github/workflows/ios.yml").read_text())
    if "build" not in workflow["jobs"] or "PacketTunnel" not in project["targets"]:
        raise ValueError("Missing build job or extension target")
    icon = Image.open(ROOT / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    if icon.size != (1024, 1024) or icon.mode != "RGB":
        raise ValueError("App icon must be 1024x1024 opaque RGB")
    print(f"Syntax parsed: {len(swift)} Swift files. YAML, plists, asset JSON and icon validated.")
    print("This does NOT verify Swift types, Apple linking, signing or VPN connectivity.")


if __name__ == "__main__":
    check()
