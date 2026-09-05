"""Build only iOS slices using the pinned libXray build implementation on macOS."""
import json
import os
import pathlib
import platform
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor"
SOURCE = VENDOR / "libxray-source"


def run(*args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True)


def checkout():
    lock = json.loads((ROOT / "scripts/native-lock.json").read_text())
    VENDOR.mkdir(exist_ok=True)
    if not SOURCE.exists():
        run("git", "init", str(SOURCE))
        run("git", "remote", "add", "origin", lock["repository"], cwd=SOURCE)
    remote = subprocess.check_output(["git", "remote", "get-url", "origin"], cwd=SOURCE, text=True).strip()
    if remote != lock["repository"]:
        raise RuntimeError("Unexpected libXray source remote")
    run("git", "fetch", "--depth=1", "origin", lock["revision"], cwd=SOURCE)
    run("git", "checkout", "--detach", lock["revision"], cwd=SOURCE)
    return lock


def build():
    if platform.system() != "Darwin":
        raise RuntimeError("Native iOS compilation requires macOS/Xcode. Use the GitHub Actions workflow.")
    checkout()
    sys.path.insert(0, str(SOURCE / "build"))
    from app.apple_go import AppleGoBuilder

    builder = AppleGoBuilder(str(SOURCE / "build"))
    builder.snapshot_go_env()
    previous = pathlib.Path.cwd()
    try:
        # There are no geo rules in Velora; skip upstream geo downloads and non-iOS slices.
        builder.init_go_env()
        builder.prepare_static_lib()
        builder.build_targets(builder.ios_targets)
        simulator = builder.ios_targets[1:]
        builder.merge_static_lib(simulator[0].sdk, [target.apple_arch for target in simulator])
        builder.create_include_dir()
        include = pathlib.Path(builder.framework_dir) / "include"
        device = pathlib.Path(builder.framework_dir) / "iphoneos-arm64" / builder.lib_file
        sim = pathlib.Path(builder.framework_dir) / "iphonesimulator-x86_64-arm64" / builder.lib_file
        output = VENDOR / "LibXray.xcframework"
        if output.exists():
            if output.resolve().parent != VENDOR.resolve():
                raise RuntimeError("Unsafe framework output path")
            shutil.rmtree(output)
        run("xcodebuild", "-create-xcframework", "-library", str(device), "-headers", str(include),
            "-library", str(sim), "-headers", str(include), "-output", str(output))
        shutil.copy2(SOURCE / "LICENSE", VENDOR / "libXray-LICENSE")
    finally:
        builder.restore_go_env()
        os.chdir(previous)


if __name__ == "__main__":
    if "--checkout-only" in sys.argv:
        checkout()
    else:
        build()
