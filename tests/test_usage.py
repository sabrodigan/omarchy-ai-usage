import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'bin/usage-run'
loader = importlib.machinery.SourceFileLoader('collector', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
collector = importlib.util.module_from_spec(spec)
loader.exec_module(collector)


def record(client='claude', output=10):
    return {'client': client, 'tokens': {'input': 3, 'output': output,
            'cacheRead': 5, 'cacheWrite': 7, 'reasoning': 2}, 'messages': 1, 'cost': .01}


def graph(*records):
    return {'contributions': [{'date': '2026-09-10', 'clients': list(records)}]}


class UsageTest(unittest.TestCase):
    def test_counts_real_counters_and_no_quota(self):
        data = collector.normalize(graph(record(), record()))
        self.assertEqual(data['total_tokens_consumed'], 54)
        self.assertEqual(data['providers'][0]['messages'], 2)
        self.assertIsNone(data['providers'][0]['quota'])
        self.assertIsNone(data['providers'][0]['percent_used'])

    def test_empty_agents_hidden_and_clients_separate(self):
        empty = {'client': 'gemini', 'tokens': {}, 'messages': 0}
        rows = collector.normalize(graph(record('claude'), record('antigravity-cli'), empty))['providers']
        self.assertEqual({r['provider_id'] for r in rows}, {'claude', 'antigravity-cli'})
        self.assertEqual(collector.normalize({'contributions': []})['providers'], [])

    def test_invalid_schema_is_error(self):
        for value in ({}, {'contributions': None}, []):
            with self.assertRaises(ValueError):
                collector.normalize(value)

    def test_fresh_process_reads_new_records(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            data = folder / 'synthetic.json'
            fake = folder / 'tokscale'
            fake.write_text('#!/usr/bin/env python3\nimport os\nprint(open(os.environ["FIXTURE"]).read())\n')
            fake.chmod(0o755)
            env = dict(os.environ, TOKSCALE_BIN=str(fake), FIXTURE=str(data),
                       USAGE_BIN='/nonexistent/usage')
            totals = []
            for output in (10, 30):
                data.write_text(json.dumps(graph(record(output=output))))
                result = subprocess.run([str(SCRIPT), 'now', '--json'], env=env,
                                        capture_output=True, text=True, check=True)
                totals.append(json.loads(result.stdout)['total_tokens_consumed'])
            self.assertEqual(totals, [27, 47])
            fake.write_text('#!/bin/sh\necho private-secret >&2\nexit 1\n')
            result = subprocess.run([str(SCRIPT)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn('private-secret', result.stdout + result.stderr)
            self.assertIn('error', json.loads(result.stdout))

    def test_dashboard_launch_arguments(self):
        with patch.object(collector, 'executable', return_value='/test/tokscale'), \
             patch.object(collector.os, 'execv', side_effect=SystemExit) as launch:
            with self.assertRaises(SystemExit):
                collector.main(['watch'])
            launch.assert_called_once_with(collector.sys.executable,
                [collector.sys.executable, str(SCRIPT.with_name('dashboard')),
                 '/test/tokscale', '--refresh', '60', 'tui', '--month'])

    def test_usage_local_rows_merge(self):
        local = {'providers': [
            {'provider_id': 'muse', 'display_name': 'Meta Muse', 'unit': 'tokens', 'consumed': 500,
             'status': 'ok', 'estimated_cost_usd': .5, 'last_activity': '2026-09-29T12:00:00Z',
             'model_or_tier': 'muse-spark-1.3 (4)', 'models': [{'model': 'muse-spark-1.3', 'requests': 4}]},
            {'provider_id': 'cursor', 'unit': 'requests', 'consumed': 3, 'status': 'ok',
             'estimated_cost_usd': 20, 'model_or_tier': 'grok-4.6 (3)',
             'models': [{'model': 'grok-4.6', 'requests': 3}]},
            {'provider_id': 'antigravity', 'unit': 'tokens', 'consumed': 9e6, 'status': 'ok'},
            {'provider_id': 'claude', 'unit': 'tokens', 'consumed': 1, 'status': 'ok',
             'models': [{'model': 'x', 'requests': 1}]}]}
        data = collector.normalize(graph(record('claude')), collector.local_rows(local))
        rows = {r['provider_id']: r for r in data['providers']}
        self.assertEqual(set(rows), {'claude', 'muse', 'cursor'})  # estimate-only antigravity skipped
        self.assertEqual(rows['claude']['consumed'], 27)  # Tokscale wins when both report
        self.assertEqual((rows['muse']['messages'], rows['muse']['last_activity']), (4, '2026-09-29'))
        self.assertEqual((rows['cursor']['unit'], rows['cursor']['estimated_cost_usd']), ('requests', 0))
        self.assertEqual(data['total_tokens_consumed'], 527)  # request counts are not tokens
        self.assertEqual(data['providers'][-1]['provider_id'], 'cursor')

    def test_usage_local_optional_and_private(self):
        with tempfile.TemporaryDirectory() as folder:
            fake = Path(folder) / 'usage'
            fake.write_text('#!/bin/sh\necho private-secret >&2\nexit 1\n')
            fake.chmod(0o755)
            with patch.dict(os.environ, {'USAGE_BIN': str(fake)}):
                self.assertEqual(collector.read_usage_local(5), [])
            with patch.dict(os.environ, {'USAGE_BIN': '/nonexistent/usage'}), \
                 patch.object(collector.shutil, 'which', return_value=None), \
                 patch.object(collector.Path, 'home', return_value=Path(folder) / 'nohome'):
                self.assertEqual(collector.read_usage_local(5), [])

    def test_missing_dependency(self):
        result = subprocess.run([str(SCRIPT)], env=dict(os.environ, TOKSCALE_BIN='/nonexistent/tokscale'),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Install Tokscale', result.stdout)


if __name__ == '__main__':
    unittest.main()
