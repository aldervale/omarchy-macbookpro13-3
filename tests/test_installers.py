# SPDX-License-Identifier: GPL-2.0-only
"""Run the actual installers in isolated trees with systemd/DKMS stubs."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="mbp-installer-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, TEST_INSTALL_ROOT=str(self.root))
        self.env["PATH"] = str(self.bin) + ":/usr/bin:/usr/sbin"
        self.target = self.root / "usr/local/libexec/macbook-touchbar"
        self.dropin = self.root / "etc/systemd/system/systemd-suspend.service.d/70-macbook-touchbar-trial.conf"
        self.stub("systemctl", '''
case $* in
  *ActiveState*) [[ ${TEST_BUS_FAIL:-0} == 0 ]] || exit 1; echo "${TEST_STATE-inactive}" ;;
  *ExecStopPost*)
    [[ ${TEST_NO_CLEANUP:-0} == 0 ]] && printf '%s ' "$TEST_INSTALL_ROOT/usr/local/sbin/macbook-suspend post"
    if [[ -e $TEST_INSTALL_ROOT/etc/systemd/system/systemd-suspend.service.d/70-macbook-touchbar-trial.conf ]]; then
      printf '%s' "$TEST_INSTALL_ROOT/usr/local/libexec/macbook-touchbar/resume"
    fi
    echo ;;
  *ExecStartPre*) echo "$TEST_INSTALL_ROOT/usr/local/sbin/macbook-suspend pre" ;;
  daemon-reload) : ;;
  *) exit 99 ;;
esac
''')
        self.stub("systemd-analyze", 'exit "${TEST_VERIFY_FAIL:-0}"\n')
        self.stub("modinfo", 'exit 0\n')
        self.stub("dkms", 'exit 0\n')
        self.stub("preflight", 'exit "${TEST_PREFLIGHT_FAIL:-0}"\n')
        model = self.root / "sys/class/dmi/id/product_name"
        model.parent.mkdir(parents=True)
        model.write_text("MacBookPro13,3\n")
        release = subprocess.check_output(["uname", "-r"], text=True).strip()
        (self.root / "usr/lib/modules" / release / "build").mkdir(parents=True)

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/bash\n" + body)
        path.chmod(0o755)

    def run_installer(self, action, installer="install-touchbar.sh", success=True):
        source = (REPO / installer).read_text()
        source = source.replace("export PATH=/usr/bin:/usr/sbin", "# fixture PATH")
        source = source.replace("[[ $EUID == 0 ]]", "[[ 1 == 1 ]]")
        for prefix in ("/sys/", "/usr/local/", "/etc/systemd/", "/run/macbook-",
                       "/run/systemd/", "/var/lib/", "/usr/src/", "/usr/lib/modules/"):
            source = source.replace(prefix, str(self.root) + prefix)
        source = source.replace('base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)',
                                'base="' + str(REPO) + '"')
        source = source.replace('/usr/bin/python3 -I "$base/touchbar/unpark.py"', "preflight")
        source = source.replace('bash "$base/persistent-sleep/macbook-suspend" check', "preflight")
        script = self.root / "installer"
        script.write_text(source)
        result = subprocess.run(["bash", str(script), action], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_touchbar_install_remove_and_file_permissions(self):
        self.run_installer("install")
        self.assertTrue(self.dropin.exists())
        self.assertEqual((self.target / "unpark.py").stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o700)
        self.run_installer("remove")
        self.assertFalse(self.target.exists())
        self.assertFalse(self.dropin.exists())

    def test_touchbar_verify_failure_rolls_back(self):
        self.env["TEST_VERIFY_FAIL"] = "1"
        self.run_installer("install", success=False)
        self.assertFalse(self.target.exists())
        self.assertFalse(self.dropin.exists())

    def test_touchbar_preflight_or_missing_cleanup_never_installs(self):
        for key in ("TEST_PREFLIGHT_FAIL", "TEST_NO_CLEANUP"):
            with self.subTest(key=key):
                self.env[key] = "1"
                self.run_installer("install", success=False)
                self.assertFalse(self.target.exists())
                del self.env[key]

    def test_existing_touchbar_install_is_preserved(self):
        self.run_installer("install")
        original = (self.target / "files.sha256").read_bytes()
        self.run_installer("install", success=False)
        self.assertEqual((self.target / "files.sha256").read_bytes(), original)

    def test_modified_touchbar_install_cannot_be_removed(self):
        self.run_installer("install")
        (self.target / "resume").write_text("administrator edit\n")
        self.run_installer("remove", success=False)
        self.assertTrue(self.dropin.exists())

    def test_retired_trial_is_refused(self):
        (self.root / "run/macbook-touchbar-trial").mkdir(parents=True)
        self.run_installer("install", success=False)
        self.assertFalse(self.target.exists())

    def test_both_installers_fail_closed_on_bus_error_or_noninactive_state(self):
        for installer in ("install-touchbar.sh", "install-persistent-sleep.sh"):
            for key, value in (("TEST_BUS_FAIL", "1"), ("TEST_STATE", "activating"),
                               ("TEST_STATE", "active"), ("TEST_STATE", "deactivating"),
                               ("TEST_STATE", "failed"), ("TEST_STATE", "")):
                with self.subTest(installer=installer, value=value):
                    self.env[key] = value
                    self.run_installer("install", installer, success=False)
                    self.assertFalse(self.target.exists())
                    self.assertFalse((self.root / "usr/src/macbook-ec-wake-0.1").exists())
                    del self.env[key]

    def test_sleep_manifest_cannot_substitute_an_unrelated_file(self):
        self.run_installer("install", "install-persistent-sleep.sh")
        manifest = self.root / "var/lib/macbook-repair/persistent-sleep-files.sha256"
        unrelated = self.root / "unrelated"
        unrelated.write_text("preserve me\n")
        manifest.write_bytes(subprocess.check_output(["sha256sum", str(unrelated)]))
        self.run_installer("remove", "install-persistent-sleep.sh", success=False)
        self.assertTrue((self.root / "usr/local/sbin/macbook-suspend").exists())
        self.assertTrue(unrelated.exists())


if __name__ == "__main__":
    unittest.main()
