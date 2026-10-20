"""Integration tests against real macOS utilities and the system Bash 3.2."""
import json
import os
from pathlib import Path
import plistlib
import pty
import select
import time
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'electron-detector.sh'

class DetectorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def app(self, name, signal='framework', version='1.2.3', folder=None, payload=0):
        app = (folder or self.root) / (name + '.app')
        (app / 'Contents').mkdir(parents=True)
        with (app / 'Contents/Info.plist').open('wb') as f:
            plistlib.dump({'CFBundleShortVersionString': version}, f)
        if signal == 'framework':
            (app / 'Contents/Frameworks/Electron Framework.framework').mkdir(parents=True)
        if signal == 'binary':
            (app / 'Contents/MacOS').mkdir()
            (app / 'Contents/MacOS/Electron').write_text('fixture')
        if payload:
            (app / 'Contents/payload').write_bytes(os.urandom(payload))
        return app

    def run_script(self, *args):
        return subprocess.run(['/bin/bash', str(SCRIPT), '--path', str(self.root), *args], text=True, capture_output=True, timeout=30)

    def report(self, *args):
        result = self.run_script('--json', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_signals_and_nested_helpers(self):
        outer = self.app('Electron app')
        self.app('Helper', folder=outer / 'Contents')
        self.app('Binary app', 'binary', folder=self.root / 'Tools' / 'Editors')
        self.app('Plain app', 'none')
        data = self.report()
        self.assertEqual(data['total_apps'], 3)
        self.assertEqual(data['electron_count'], 2)
        self.assertEqual({a['name'] for a in data['electron_apps']}, {'Electron app', 'Binary app'})

    def test_json_escapes_unusual_names_and_versions(self):
        name = 'Café "quoted" \\ path|tab\tline\nname'
        version = '1"\\\t\n2'
        self.app(name, version=version)
        data = self.report()
        self.assertEqual(data['electron_apps'][0]['name'], name)
        self.assertEqual(data['electron_apps'][0]['version'], version)
        self.assertNotIn(str(self.root), json.dumps(data))

    def test_deduplicate_overlapping_paths_and_symlink(self):
        app = self.app('One')
        (self.root / 'Alias.app').symlink_to(app, target_is_directory=True)
        self.assertEqual(self.report('--path', str(self.root))['total_apps'], 1)

    def test_empty_is_valid_report(self):
        data = self.report()
        self.assertEqual(data['total_apps'], 0)
        self.assertEqual(data['electron_apps'], [])

    def test_no_false_native_claim(self):
        self.app('Another framework', 'none')
        result = self.run_script()
        self.assertIn('does not prove an app is native', result.stdout)
        self.assertEqual(self.report()['electron_count'], 0)

    def test_sizes_are_sorted_and_totaled(self):
        self.app('Small')
        self.app('Large', payload=300000)
        data = self.report()
        self.assertEqual(data['electron_apps'][0]['name'], 'Large')
        self.assertEqual(data['total_size_kb'], sum(a['size_kb'] for a in data['electron_apps']))

    def test_share_omits_names_and_quiet_omits_promotion(self):
        self.app('PrivateWorkApp')
        shared = self.run_script('--share').stdout
        self.assertNotIn('PrivateWorkApp', shared)
        self.assertNotIn(str(self.root), shared)
        self.assertIn('1 of 1', shared)
        self.assertNotIn('macnative.io', self.run_script('--quiet').stdout)

    def test_missing_version_and_terminal_escape_sanitizing(self):
        app = self.app('Escape\x1b[31m')
        (app / 'Contents/Info.plist').unlink()
        data = self.report()
        self.assertEqual(data['electron_apps'][0]['version'], 'Unknown')
        self.assertNotIn('\x1b', self.run_script('--quiet').stdout)

    def test_invalid_path_and_noninteractive_menu(self):
        self.assertEqual(self.run_script('--path', '/does-not-exist').returncode, 2)
        self.assertEqual(self.run_script('--interactive').returncode, 2)
        self.assertEqual(self.run_script('--bogus').returncode, 2)


    def test_demo_is_explicit_and_does_not_scan(self):
        self.app('PrivateWorkApp')
        result = subprocess.run(['/bin/bash', str(SCRIPT), '--demo'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('DEMO / fictional apps and sizes. Nothing scanned.', result.stdout)
        self.assertIn('Example Editor', result.stdout)
        self.assertNotIn('PrivateWorkApp', result.stdout)
        shared = subprocess.check_output(['/bin/bash', str(SCRIPT), '--demo', '--share'], text=True)
        self.assertTrue(shared.startswith('DEMO /'))

    def test_conflicting_output_modes(self):
        self.assertEqual(self.run_script('--json', '--share').returncode, 2)
        self.assertEqual(self.run_script('--demo').returncode, 2)  # --path supplied by helper
        result = subprocess.run(['/bin/bash', str(SCRIPT), '--demo', '--json'], capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, b'')

    def test_relative_root_starting_with_dash(self):
        folder = self.root / '-apps'
        self.app('Example', folder=folder)
        result = subprocess.run(['/bin/bash', str(SCRIPT), '--path', '-apps', '--json'],
                                cwd=self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['electron_count'], 1)

    def test_unknown_size_is_not_zero(self):
        self.app('Unreadable size')
        commands = self.root / 'bin'
        commands.mkdir()
        du = commands / 'du'
        du.write_text('#!/bin/sh\nexit 1\n')
        du.chmod(0o755)
        result = subprocess.run(['/bin/bash', str(SCRIPT), '--path', str(self.root), '--json'],
                                env={**os.environ, 'PATH': str(commands) + ':' + os.environ['PATH']},
                                text=True, capture_output=True)
        data = json.loads(result.stdout)
        self.assertEqual(data['unknown_sizes'], 1)
        self.assertIsNone(data['electron_apps'][0]['size_kb'])
        self.assertEqual(data['total_size_kb'], 0)

    def test_symlink_loop_does_not_duplicate_apps(self):
        self.app('Readable')
        (self.root / 'loop').symlink_to(self.root, target_is_directory=True)
        data = self.report()
        self.assertEqual(data['electron_count'], 1)
        self.assertEqual(data['total_apps'], 1)

    def test_interactive_menu_in_real_terminal(self):
        commands = self.root / 'bin'
        commands.mkdir()
        for name, command in [('pbcopy', 'cat > "$DETECTOR_TEST_OUTPUT/clipboard"'),
                              ('open', 'printf "%s" "$1" > "$DETECTOR_TEST_OUTPUT/url"')]:
            stub = commands / name
            stub.write_text('#!/bin/sh\n' + command + '\n')
            stub.chmod(0o755)
        master, slave = pty.openpty()
        process = subprocess.Popen(['/bin/bash', str(SCRIPT), '--demo', '--interactive', '--no-color'],
                                   stdin=slave, stdout=slave, stderr=slave,
                                   env={**os.environ, 'TERM': 'dumb', 'DETECTOR_TEST_OUTPUT': str(self.root),
                                        'PATH': str(commands) + ':' + os.environ['PATH']})
        os.close(slave)
        output = b''
        sent = False
        deadline = time.monotonic() + 10
        try:
            while time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.1)
                if ready:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError:
                        break
                    if not chunk:
                        break
                    output += chunk
                    if b'  > ' in output and not sent:
                        os.write(master, b'e\ns\nc\na\nq\n')
                        sent = True
                elif process.poll() is not None:
                    break
            process.wait(timeout=2)
            text = output.decode()
            self.assertEqual(process.returncode, 0, text)
            self.assertIn('The clues:', text)
            self.assertIn('My Mac app census: 3 of 42', text)
            self.assertNotIn('\x1b', text)
            self.assertIn('3 of 42', (self.root / 'clipboard').read_text())
            self.assertNotIn('Example Editor', (self.root / 'clipboard').read_text())
            self.assertEqual((self.root / 'url').read_text(), 'https://macnative.io/categories')
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

if __name__ == '__main__':
    unittest.main()
