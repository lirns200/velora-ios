"""Collect the pinned Go module inventory and upstream notices before XcodeGen."""
import json
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Vendor/libxray-source"
OUTPUT = ROOT / "App/Resources/ThirdPartyLicenses"


def json_stream(text):
    decoder = json.JSONDecoder()
    position = 0
    while position < len(text):
        if text[position].isspace():
            position += 1
            continue
        item, position = decoder.raw_decode(text, position)
        yield item


def collect():
    subprocess.run(["go", "mod", "download", "all"], cwd=SOURCE, check=True)
    raw = subprocess.check_output(["go", "list", "-m", "-json", "all"], cwd=SOURCE, text=True)
    inventory = []
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for module in json_stream(raw):
        inventory.append({key: module[key] for key in ("Path", "Version", "Sum") if key in module})
        directory = pathlib.Path(module.get("Dir", ""))
        if not module.get("Dir") or not directory.is_dir():
            raise RuntimeError(f"Missing downloaded module: {module['Path']}")
        destination = OUTPUT / module["Path"].replace("/", "_").replace(":", "_")
        for file in directory.rglob("*"):
            if not file.is_file() or file.is_symlink():
                continue
            if not file.name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE", "COPYRIGHT")):
                continue
            relative = file.relative_to(directory)
            # The main module lives inside this project, but notices are outside its source tree.
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file, target)
    go_root = pathlib.Path(subprocess.check_output(["go", "env", "GOROOT"], text=True).strip())
    shutil.copy2(go_root / "LICENSE", OUTPUT / "Go-LICENSE.txt")
    shutil.copy2(ROOT / "THIRD-PARTY-NOTICES.md", OUTPUT / "Velora-ThirdPartyNotices.txt")
    (OUTPUT / "go-dependencies.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(f"Collected notices for {len(inventory)} Go modules")


if __name__ == "__main__":
    collect()
