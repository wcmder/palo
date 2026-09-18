import argparse
import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from palo_cli import push_all


class PushAllTest(unittest.TestCase):
    def options(self, **changes):
        return argparse.Namespace(dry_run=changes.get('dry_run', False), auto_approve=changes.get('auto_approve', True))

    def run_batch(self, options, process):
        with patch.object(push_all.subprocess, 'run', process), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return push_all.run(options, Path('/workspace/env/lab'), {'PANOS_PASSWORD': 'secret', 'TF_CLI_ARGS_apply': '-destroy'}, '/bin/terraform')

    def discovery(self, targets):
        return Mock(returncode=0, stdout=json.dumps(json.dumps(targets)))

    def test_sequential_pushes_preserve_credentials_outside_arguments(self):
        process = Mock(side_effect=[self.discovery({'z/hub': {'serials': ['B']}, 'a/spoke': {'serials': ['A']}}), Mock(returncode=0), Mock(returncode=0)])
        self.assertEqual(self.run_batch(self.options(), process), 0)
        calls = process.call_args_list
        self.assertEqual(calls[0].kwargs['input'], 'jsonencode(local.deployment_items)\n')
        self.assertEqual(calls[1].args[0][-1], '-invoke=module.deployment.action.panos_push_to_devices.this["a/spoke"]')
        self.assertEqual(calls[2].args[0][-1], '-invoke=module.deployment.action.panos_push_to_devices.this["z/hub"]')
        for call in calls:
            self.assertNotIn('secret', ' '.join(call.args[0]))
            self.assertEqual(call.kwargs['env']['PANOS_PASSWORD'], 'secret')
            self.assertNotIn('TF_CLI_ARGS_apply', call.kwargs['env'])

    def test_stop_on_first_failed_push(self):
        process = Mock(side_effect=[self.discovery({'a/x': {'serials': ['A']}, 'b/y': {'serials': ['B']}, 'c/z': {'serials': ['C']}}), Mock(returncode=0), Mock(returncode=2)])
        self.assertEqual(self.run_batch(self.options(), process), 2)
        self.assertEqual(process.call_count, 3)

    def test_dry_run_and_empty_targets_never_apply(self):
        for targets, options in [({}, self.options()), ({'a/x': {'serials': ['A']}}, self.options(dry_run=True))]:
            process = Mock(return_value=self.discovery(targets))
            self.assertEqual(self.run_batch(options, process), 0)
            self.assertEqual(process.call_count, 1)

    def test_confirmation_and_cancellation(self):
        for answer, expected_calls in [('no', 1), ('yes', 2)]:
            process = Mock(side_effect=[self.discovery({'a/x': {'serials': ['A']}}), Mock(returncode=0)])
            with patch('builtins.input', return_value=answer):
                self.assertEqual(self.run_batch(self.options(auto_approve=False), process), 0)
            self.assertEqual(process.call_count, expected_calls)

    def test_discovery_errors_never_push(self):
        for result in [Mock(returncode=1), Mock(returncode=0, stdout='(known after apply)'), self.discovery({'bad': {'serials': []}}), self.discovery([])]:
            process = Mock(return_value=result)
            self.assertEqual(self.run_batch(self.options(), process), 1)
            self.assertEqual(process.call_count, 1)

    def test_help_skips_credentials(self):
        from palo_cli import cli
        with patch.object(cli.sys, 'argv', ['palo', 'lab', 'push-all', '--help']), patch.object(cli, 'workspace_root', return_value=Path('/workspace')), patch.object(cli, 'prepare') as prepare, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                cli.main()
            self.assertEqual(result.exception.code, 0)
            prepare.assert_not_called()


if __name__ == '__main__':
    unittest.main()
