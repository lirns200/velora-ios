# Validation record — 2026-09-05

## GitHub build verified

[Run 33979661256](https://github.com/lirns200/velora-ios/actions/runs/33979661256) completed with **success** for app-code commit `0bbb1ed6c6ec282f1490b2a551340783b3dd1cf1`.

- All **11 Swift tests** passed on the macOS runner.
- All **4 Python packaging tests** passed.
- Pinned libXray compiled for iPhone arm64 and simulator arm64/x86_64.
- Xcode compiled the simulator app and PacketTunnel extension.
- Xcode compiled the Release iPhone app and PacketTunnel extension.
- Workflow produced and uploaded **Velora-unsigned-IPA**, version **1.0.0**, build **2**.
- Downloaded artifact ZIP and nested IPA passed ZIP integrity checks. Both Mach-O executables, executable permissions, bundle IDs and SHA256 were verified locally.

IPA SHA256: `c6c5195cc9bc115767fed57ffec665634dde7487154440e84fefd7487fd21d64`.

The first run failed because the app's `Subscription` model conflicted with `Combine.Subscription`. App references now explicitly use `VPNCore.Subscription`; the subsequent complete Xcode builds passed. Native-library caching now saves immediately after compilation so a later app build failure does not discard it.

**Still unverified:** final PC signing, installation on a physical iPhone and actual VLESS/Reality connectivity. No signing profiles or test-server credentials were supplied. The IPA is intentionally unsigned.

The sections below preserve the checks and limitations from the initial Windows-only source preparation; the successful GitHub run above supersedes their compiler/build limitations.

## Executed on Windows

- `python -m unittest discover -s scripts/tests -v`: **4 passed**. Tests cover IPA inclusion of the tunnel executable, Unix executable permissions, missing-extension rejection, bundle-ID mismatch rejection, and rejection of output inside the app bundle.
- `python scripts/check_sources.py`: **16 Swift files parsed without syntax errors**; YAML, property lists, entitlement property lists, asset JSON and 1024×1024 opaque app icon validated. This is tree-sitter parsing, not Swift type checking.
- `python -m compileall -q scripts`: Python scripts compiled without syntax errors.
- `actionlint 1.7.12 -shellcheck='' -pyflakes='' .github/workflows/ios.yml`: passed. Shellcheck/pyflakes were disabled; this validates Actions syntax and expressions, not macOS commands at runtime.
- `git diff --check`: passed.
- Independent static review checked the C bridge, native slice paths, pinned API, TUN descriptor handling, HTTPS constraints, shared Keychain setup and start/stop serialization. The dependency notice step was changed to `go mod download all` so that it matches the complete module inventory.
- Source archive is exported separately with `scripts/export_source.py`, which checks ZIP integrity and required project files. No Git history or signing material is included.

## Initially not executed (before GitHub publication)

- The **11 Swift package test methods**: the Windows environment has no Swift compiler. `swift test --package-path Packages/VPNCore` could not start. They are configured as a required first step of GitHub Actions.
- Native Go-to-iOS compilation, Xcode simulator/device builds and actual IPA creation: these require macOS/Xcode. The build script rejects Windows with an explicit explanation.
- GitHub Actions: no destination repository was supplied or created in this session.
- Device installation and network connectivity: no signed build, provisioning profiles, iPhone session or VLESS test server was available.

At that initial stage, the delivered artifact was source code plus build automation. A compiled unsigned IPA is now available from the verified GitHub run above. No claim of successful device installation or connectivity is made.
