"""Operator actions use the user's credential and stop only the selected build."""
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('control', Path(__file__).resolve().parents[2] / 'control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


def response(value):
    return io.BytesIO(json.dumps(value).encode())


class OperatorControl(unittest.TestCase):
    def test_finished_build_needs_neither_credentials_nor_stop(self):
        client = control.Controller('http://127.0.0.1:8010', Path('/not-present'))
        client.opener = Mock()
        client.opener.open.return_value = response({'builds': [{'buildid': 258, 'complete': True}]})
        self.assertEqual(client.cancel(258)['status'], 'already finished')
        self.assertEqual(client.opener.open.call_count, 1)

    def test_mismatched_response_never_stops_another_build(self):
        client = control.Controller('http://127.0.0.1:8010', Path('/not-present'))
        client.opener = Mock()
        client.opener.open.return_value = response({'builds': [{'buildid': 259, 'complete': False}]})
        with self.assertRaisesRegex(ValueError, 'different build'):
            client.cancel(258)
        self.assertEqual(client.opener.open.call_count, 1)

    def test_cancel_authenticates_and_preserves_server_rejection(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            (state / 'secrets').mkdir()
            (state / 'secrets/operator-password').write_text('test-only')
            client = control.Controller('http://127.0.0.1:8010', state)
            client.opener = Mock()
            client.opener.open.side_effect = [
                response({'builds': [{'buildid': 258, 'complete': False}]}),
                response({}), response({'error': {'message': 'not authorized'}}),
            ]
            with self.assertRaisesRegex(RuntimeError, 'not authorized'):
                client.cancel(258)
            login = client.opener.open.call_args_list[1].args[0]
            self.assertTrue(login.has_header('Authorization'))
            request = client.opener.open.call_args_list[2].args[0]
            self.assertEqual(request.full_url, 'http://127.0.0.1:8010/api/v2/builds/258')
            self.assertFalse(request.has_header('Authorization'))
            self.assertEqual(json.loads(request.data)['method'], 'stop')


if __name__ == '__main__':
    unittest.main()
