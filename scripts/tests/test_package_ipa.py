import importlib.util
import pathlib
import plistlib
import tempfile
import unittest
import zipfile

SCRIPT = pathlib.Path(__file__).parents[1] / "package_ipa.py"


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.app = self.root / "Velora.app"
        self.extension = self.app / "PlugIns" / "PacketTunnel.appex"
        self.extension.mkdir(parents=True)
        for directory, bundle, executable in [
            (self.app, "app.velora.client", "Velora"),
            (self.extension, "app.velora.client.PacketTunnel", "PacketTunnel"),
        ]:
            (directory / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": bundle, "CFBundleExecutable": executable,
            }))
            (directory / executable).write_bytes(b"fixture executable")

    def module(self):
        self.assertTrue(SCRIPT.exists(), "IPA packager has not been implemented")
        spec = importlib.util.spec_from_file_location("package_ipa", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_packages_extension_and_executable_permissions(self):
        output = self.root / "Velora-unsigned.ipa"
        self.module().package(self.app, output)
        with zipfile.ZipFile(output) as archive:
            self.assertIn("Payload/Velora.app/PlugIns/PacketTunnel.appex/PacketTunnel", archive.namelist())
            info = archive.getinfo("Payload/Velora.app/Velora")
            self.assertEqual((info.external_attr >> 16) & 0o777, 0o755)
        self.assertTrue(output.with_suffix(".ipa.sha256").exists())

    def test_missing_tunnel_is_rejected_without_artifact(self):
        (self.extension / "PacketTunnel").unlink()
        output = self.root / "bad.ipa"
        with self.assertRaises(ValueError):
            self.module().package(self.app, output)
        self.assertFalse(output.exists())

    def test_rejects_wrong_extension_bundle_identifier(self):
        (self.extension / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "wrong.extension", "CFBundleExecutable": "PacketTunnel",
        }))
        with self.assertRaises(ValueError):
            self.module().package(self.app, self.root / "bad.ipa")

    def test_output_inside_bundle_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module().package(self.app, self.app / "bad.ipa")


if __name__ == "__main__":
    unittest.main()
