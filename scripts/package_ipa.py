"""Package an unsigned device build. This does not sign or make it installable."""
import argparse
import hashlib
import pathlib
import plistlib
import stat
import zipfile


def package(app: pathlib.Path, output: pathlib.Path) -> None:
    app, output = app.resolve(), output.resolve()
    if not app.is_dir() or app.suffix != ".app" or output.is_relative_to(app):
        raise ValueError("Expected an .app directory and an output outside it")
    extension = app / "PlugIns" / "PacketTunnel.appex"
    executables = set()
    bundles = []
    for directory in (app, extension):
        plist = directory / "Info.plist"
        if not plist.is_file():
            raise ValueError("App or packet-tunnel extension Info.plist is missing")
        info = plistlib.loads(plist.read_bytes())
        name = info.get("CFBundleExecutable", "")
        if not name or pathlib.Path(name).name != name or not (directory / name).is_file():
            raise ValueError("App or packet-tunnel executable is missing")
        executables.add(directory / name)
        bundles.append(info.get("CFBundleIdentifier", ""))
    if not bundles[0] or bundles[1] != bundles[0] + ".PacketTunnel":
        raise ValueError("Packet tunnel bundle ID must match app bundle ID + .PacketTunnel")
    files = sorted(p for p in app.rglob("*") if p.is_file())
    if any(p.is_symlink() for p in app.rglob("*")):
        raise ValueError("Unexpected symlink in iOS bundle")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".ipa.tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for file in files:
                relative = pathlib.PurePosixPath("Payload") / app.name / pathlib.PurePosixPath(file.relative_to(app))
                entry = zipfile.ZipInfo(str(relative))
                entry.create_system = 3
                mode = 0o755 if file in executables or file.stat().st_mode & stat.S_IXUSR else 0o644
                entry.external_attr = (stat.S_IFREG | mode) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(entry, file.read_bytes())
        temporary.replace(output)
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        output.with_suffix(".ipa.sha256").write_text(f"{digest}  {output.name}\n", encoding="utf-8")
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    package(args.app, args.output)
    print(f"Created UNSIGNED artifact: {args.output}")
