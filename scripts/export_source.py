"""Export only the VPN project, without Git history, credentials or build output."""
import argparse
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def export(destination):
    files = []
    for name in ("App", "Tunnel", "Shared", "Packages", "scripts", ".github"):
        for path in (ROOT / name).rglob("*"):
            if not path.is_file() or path.is_symlink():
                continue
            if any(part in ("__pycache__", ".build", ".swiftpm", "ThirdPartyLicenses") for part in path.relative_to(ROOT).parts):
                continue
            files.append(path)
    files += [ROOT / name for name in ("README.md", "THIRD-PARTY-NOTICES.md", "project.yml", ".gitignore", ".gitattributes", "docs/WINDOWS-RU.md", "docs/VALIDATION.md")]
    destination = pathlib.Path(destination).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(files):
            if file.suffix.lower() in (".p12", ".mobileprovision", ".ipa", ".pyc"):
                raise ValueError("Unexpected signing/build artifact in source export")
            archive.write(file, file.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise ValueError("Source ZIP integrity check failed")
        names = set(archive.namelist())
        for required in (".github/workflows/ios.yml", "project.yml", "App/VeloraApp.swift", "Tunnel/PacketTunnelProvider.swift", "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"):
            if required not in names:
                raise ValueError(f"Missing source file: {required}")
    print(f"Exported {len(files)} source files: {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination")
    export(parser.parse_args().destination)
