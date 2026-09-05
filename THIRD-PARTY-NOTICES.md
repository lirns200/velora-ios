# Third-party notices

Velora includes libXray and Xray-core in its packet tunnel extension when built. These upstream components are independently maintained. The native revision and API contract are recorded in `scripts/native-lock.json`.

## libXray — MIT

Source: https://github.com/XTLS/libXray/tree/33517b045fabde2cc95c4d43d04cb3b81d441f21

Copyright (c) 2023-2025 XTLS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Xray-core — Mozilla Public License 2.0

Unmodified source used by the pinned wrapper:
https://github.com/XTLS/Xray-core/tree/5ca6f4b7d4dc

License text: https://github.com/XTLS/Xray-core/blob/5ca6f4b7d4dc/LICENSE

## Transitive Go dependencies

The exact dependency versions and integrity hashes are in the pinned libXray
`go.mod` and `go.sum`. The workflow preserves a `go-dependencies.json` inventory
and the dependency license files with the downloadable build artifact and in
the app bundle. Source URLs follow each module path/version in the inventory.

## Build tooling

XcodeGen (MIT): https://github.com/yonaskolb/XcodeGen
Swift: https://swift.org
Go: https://go.dev

The Velora name, app icon and interface in this project are original work;
no Happ branding or application code is included.
