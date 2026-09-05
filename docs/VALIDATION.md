# Validation record — 2026-09-05

## Executed on Windows

- `python -m unittest discover -s scripts/tests -v`: **4 passed**. Tests cover IPA inclusion of the tunnel executable, Unix executable permissions, missing-extension rejection, bundle-ID mismatch rejection, and rejection of output inside the app bundle.
- `python scripts/check_sources.py`: **16 Swift files parsed without syntax errors**; YAML, property lists, entitlement property lists, asset JSON and 1024×1024 opaque app icon validated. This is tree-sitter parsing, not Swift type checking.
- `python -m compileall -q scripts`: Python scripts compiled without syntax errors.
- `actionlint 1.7.12 -shellcheck='' -pyflakes='' .github/workflows/ios.yml`: passed. Shellcheck/pyflakes were disabled; this validates Actions syntax and expressions, not macOS commands at runtime.
- `git diff --check`: passed.
- Independent static review checked the C bridge, native slice paths, pinned API, TUN descriptor handling, HTTPS constraints, shared Keychain setup and start/stop serialization. The dependency notice step was changed to `go mod download all` so that it matches the complete module inventory.
- Source archive is exported separately with `scripts/export_source.py`, which checks ZIP integrity and required project files. No Git history or signing material is included.

## Not executed

- The **11 Swift package test methods**: the Windows environment has no Swift compiler. `swift test --package-path Packages/VPNCore` could not start. They are configured as a required first step of GitHub Actions.
- Native Go-to-iOS compilation, Xcode simulator/device builds and actual IPA creation: these require macOS/Xcode. The build script rejects Windows with an explicit explanation.
- GitHub Actions: no destination repository was supplied or created in this session.
- Device installation and network connectivity: no signed build, provisioning profiles, iPhone session or VLESS test server was available.

The delivered artifact is **source code plus build automation**. It is not a verified installable IPA or a claim that this VPN has passed device testing. First CI and device runs may reveal Apple compiler, linker, signing or runtime issues that static checks cannot establish.
