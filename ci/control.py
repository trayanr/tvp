#!/usr/bin/env python3
"""Routine CI control from the controller owner's account; no sudo required."""

import argparse
import base64
import http.cookiejar
import json
from pathlib import Path
import subprocess
import urllib.error
import urllib.request


class Controller:
    def __init__(self, url, state):
        self.url = url.rstrip('/')
        self.state = state
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def get(self, path):
        with self.opener.open(self.url + '/api/v2/' + path, timeout=20) as response:
            return json.load(response)

    def cancel(self, build):
        current = self.get(f'builds/{build}')['builds'][0]
        if current['buildid'] != build:
            raise ValueError('Controller returned a different build')
        if current['complete']:
            return {'build': build, 'status': 'already finished'}
        password = (self.state / 'secrets/operator-password').read_bytes().strip()
        authorization = base64.b64encode(b'operator:' + password).decode('ascii')
        request = urllib.request.Request(self.url + '/auth/login',
                                         headers={'Authorization': 'Basic ' + authorization})
        with self.opener.open(request, timeout=20) as response:
            response.read()
        request = urllib.request.Request(self.url + f'/api/v2/builds/{build}',
            data=json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': 'stop',
                             'params': {'reason': 'Cancelled by the CI operator'}}).encode(),
            headers={'Content-Type': 'application/json'})
        with self.opener.open(request, timeout=20) as response:
            result = json.load(response)
        if result.get('error'):
            raise RuntimeError(result['error'].get('message', 'Cancellation rejected'))
        return {'build': build, 'status': 'cancellation requested'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8010')
    parser.add_argument('--state', type=Path,
                        default=Path.home() / '.local/state/tvp-ci/controller')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('status')
    cancel = commands.add_parser('cancel')
    cancel.add_argument('build', type=int)
    commands.add_parser('restart-controller')
    commands.add_parser('restart-worker')
    args = parser.parse_args()
    try:
        if args.command.startswith('restart-'):
            target = args.command.removeprefix('restart-')
            command = ['systemctl', '--no-ask-password']
            if target == 'controller':
                command.append('--user')
            return subprocess.run(command + ['restart', f'tvp-{target}.service']).returncode
        controller = Controller(args.url, args.state)
        if args.command == 'cancel':
            if args.build < 1:
                raise ValueError('Build ID must be positive')
            result = controller.cancel(args.build)
        else:
            result = controller.get('builds?complete=false&limit=20')
        print(json.dumps(result, indent=2))
        return 0
    except (OSError, ValueError, RuntimeError, urllib.error.URLError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    raise SystemExit(main())
