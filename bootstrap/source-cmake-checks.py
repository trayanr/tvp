"""Bounded installed-tool checks. Every command retains output and exit status."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time


def run(name, args, cwd=None, env=None, ok=True):
    p = subprocess.run(list(map(str, args)), cwd=cwd, env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (evidence / (name + '.log')).write_text(p.stdout)
    (evidence / (name + '.status')).write_text(str(p.returncode) + '\n')
    if ok and p.returncode:
        raise RuntimeError(name + ': ' + p.stdout)
    return p


if sys.argv[1] == 'installed':
    out, evidence = map(Path, sys.argv[2:])
    for generator in ['make', 'ninja']:
        p = run(generator + '-installed', [out / generator / 'bin/answer'], env={})
        assert p.stdout.strip() == '42'
        run(generator + '-loader', [out / generator / 'bin/answer'], env={'LD_DEBUG': 'libs'})
    for target in ['shared', 'archive', 'pkg-shared', 'pkg-static']:
        assert run('json-' + target + '-installed', [out / 'json/bin' / target], env={}).stdout.strip() == 'ok'
    sys.exit(0)

out, evidence = map(Path, sys.argv[1:3])
c = json.loads(sys.argv[3])
(evidence / 'selection.json').write_text(json.dumps(c, indent=2))
assert all(c['contracts'].values())
cmake, ctest, cpack = [c[k] for k in ['cmake', 'ctest', 'cpack']]
for tool in [cmake, ctest, cpack]:
    assert '4.4.5' in run(Path(tool).name + '-version', [tool, '--version'], env={}).stdout
caps = json.loads(run('capabilities', [cmake, '-E', 'capabilities'], env={}).stdout)
assert {g['name'] for g in caps['generators']} >= {'Unix Makefiles', 'Ninja'}
Path('module.cmake').write_text('message(STATUS "ROOT=${CMAKE_ROOT}")\ninclude(CMakeParseArguments)\n')
root = run('module-root', [cmake, '-P', 'module.cmake'], env={}).stdout
assert str(Path(cmake).parent.parent / 'share/cmake-4.4') in root
for gen, program in [('make', c['make']), ('ninja', c['ninja'])]:
    source = Path(gen + '-source'); source.mkdir()
    for name, path in c['fixture'].items(): shutil.copyfile(path, source / name)
    (source / 'marker.h').write_text('#define BUILD_MARKER 1\n')
    with (source / 'CMakeLists.txt').open('a') as stream: stream.write('\ninclude(ExternalProject)\n')
    answer = source / 'answer.c'
    answer.write_text('#include "marker.h"\n' + answer.read_text())
    build = Path(gen + '-build'); prefix = out / gen
    run(gen + '-configure', [cmake, '-S', source, '-B', build, '-G', 'Ninja' if gen == 'ninja' else 'Unix Makefiles',
        '-DCMAKE_MAKE_PROGRAM=' + program, '-DCMAKE_INSTALL_PREFIX=' + str(prefix),
        '-DCMAKE_INSTALL_LIBDIR=lib', '-DCMAKE_BUILD_TYPE=Release',
        '-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF', '-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF'])
    cache = (build / 'CMakeCache.txt').read_text()
    assert c['zlib'] + '/lib/libz.so' in cache
    assert c['zlib'] + '/include' in cache
    assert 'Iconv_IS_BUILT_IN:INTERNAL=1' in cache
    (evidence / (gen + '-cache.txt')).write_text(cache)
    compiler_logs = evidence / (gen + '-compiler')
    compiler_logs.mkdir()
    shutil.copyfile(build / 'CMakeFiles/CMakeConfigureLog.yaml', compiler_logs / 'CMakeConfigureLog.yaml')
    for metadata in (build / 'CMakeFiles/4.4.5').glob('CMake*Compiler.cmake'):
        shutil.copyfile(metadata, compiler_logs / metadata.name)
    if gen == 'make':
        assert 'SHELL = ' + c['shell'] in (build / 'CMakeFiles/answer.dir/build.make').read_text()
    run(gen + '-build', [cmake, '--build', build, '--parallel', os.environ['NIX_BUILD_CORES']])
    p = run(gen + '-ctest', [ctest, '--test-dir', build, '--output-on-failure'])
    assert '100% tests passed out of 2' in p.stdout
    run(gen + '-noop', [cmake, '--build', build, '--verbose'])
    objects = sorted(build.rglob('answer.c.o')); assert objects
    before = [p.stat().st_mtime_ns for p in objects]
    time.sleep(1.1)
    (source / 'marker.h').write_text('#define BUILD_MARKER 2\n')
    run(gen + '-header-rebuild', [cmake, '--build', build, '--verbose'])
    assert all(p.stat().st_mtime_ns > t for p, t in zip(objects, before))
    before = [p.stat().st_mtime_ns for p in objects]
    time.sleep(1.1)
    answer.write_text(answer.read_text() + '\n/* source rebuild */\n')
    run(gen + '-source-rebuild', [cmake, '--build', build, '--verbose'])
    assert all(p.stat().st_mtime_ns > t for p, t in zip(objects, before))
    before = [p.stat().st_mtime_ns for p in objects]
    run(gen + '-final-noop', [cmake, '--build', build, '--verbose'])
    assert [p.stat().st_mtime_ns for p in objects] == before
    run(gen + '-install', [cmake, '--install', build])
    # Real compile failure must cross the chosen build tool and CMake boundary.
    answer.write_text(answer.read_text() + '\n#error expected_failure_probe\n')
    assert run(gen + '-expected-failure', [cmake, '--build', build], ok=False).returncode != 0
    if gen == 'make':
        answer.write_text(answer.read_text().replace('#error expected_failure_probe', ''))
        run('archive-rebuild', [cmake, '--build', build])
        for format_, suffix in [('TXZ', 'xz'), ('TGZ', 'gz'), ('TBZ2', 'bz2'), ('TZST', 'zst')]:
            run('cpack-' + format_, [cpack, '-G', format_], cwd=build)
            archive = next(build.glob('answer-*.tar.' + suffix)).resolve()
            listing = run('archive-list-' + format_, [cmake, '-E', 'tar', 'tf', archive]).stdout
            assert '/bin/answer' in listing
            dest = Path('extract-' + format_); dest.mkdir()
            run('archive-extract-' + format_, [cmake, '-E', 'tar', 'xf', archive], cwd=dest)
            payload = next(dest.rglob('bin/answer'))
            assert payload.read_bytes() == (prefix / 'bin/answer').read_bytes()

source = Path('json-source'); source.mkdir()
(source / 'CMakeLists.txt').write_text('''cmake_minimum_required(VERSION 3.16)
project(json_consumer C)
find_package(json-c CONFIG REQUIRED)
add_executable(shared "''' + c['api'] + '''")
target_link_libraries(shared PRIVATE json-c::json-c)
add_executable(archive "''' + c['api'] + '''")
target_link_libraries(archive PRIVATE json-c::json-c-static m)
install(TARGETS shared archive DESTINATION bin)
''')
run('json-configure', [cmake, '-S', source, '-B', 'json-build', '-G', 'Unix Makefiles',
    '-DCMAKE_MAKE_PROGRAM=' + c['make'], '-DCMAKE_INSTALL_PREFIX=' + str(out / 'json')])
run('json-build', [cmake, '--build', 'json-build', '--parallel', os.environ['NIX_BUILD_CORES']])
run('json-install', [cmake, '--install', 'json-build'])
for static in [False, True]:
    flags = run('json-pkgconfig-' + str(static), [c['pkgConfig'], '--cflags', '--libs'] + (['--static'] if static else []) + ['json-c'],
                env=dict(os.environ, PKG_CONFIG_LIBDIR=c['jsonC'] + '/lib/pkgconfig')).stdout.split()
    if static:
        flags = [c['jsonC'] + '/lib/libjson-c.a' if x == '-ljson-c' else x for x in flags]
    run('json-pkgcompile-' + str(static), [os.environ['CC'], c['api'], '-o', out / 'json/bin' / ('pkg-static' if static else 'pkg-shared')] + flags)

# Direct upstream script harness: production BUILD_TESTING stays OFF.
Path('upstream').mkdir()
run('upstream-unpack', ['tar', '-xzf', c['source'], '--strip-components=1', '-C', 'upstream'])
summary = {}
for family in ['string', 'list', 'math', 'message']:
    tests = Path('upstream/Tests/RunCMake').resolve()
    p = run('upstream-' + family, [cmake, '-DCMAKE_MODULE_PATH=' + str(tests),
        '-DRunCMake_GENERATOR=Unix Makefiles', '-DRunCMake_SOURCE_DIR=' + str(tests / family),
        '-DRunCMake_BINARY_DIR=' + str(Path('run-' + family).resolve()),
        '-DRunCMake_MAKE_PROGRAM=' + c['make'], '--trace-expand', '--trace-format=json-v1',
        '--trace-source=' + str(tests / 'RunCMake.cmake'),
        '--trace-redirect=' + str(evidence / ('upstream-' + family + '.trace.jsonl')), '-P', tests / family / 'RunCMakeTest.cmake'])
    count = p.stdout.count(' - PASSED')
    assert count > 0, p.stdout
    trace = [json.loads(line) for line in (evidence / ('upstream-' + family + '.trace.jsonl')).read_text().splitlines()]
    harness = (tests / 'RunCMake.cmake').read_text().splitlines()
    result_line = next(i + 1 for i, line in enumerate(harness) if 'if(NOT "${actual_result}" MATCHES "${expect_result}")' in line)
    results = [line['args'] for line in trace if line.get('line') == result_line and line.get('cmd') == 'if']
    assert len(results) == count
    summary[family] = {'passed': count, 'status': p.returncode, 'measuredResults': results,
        'expectedNonzero': sum(r[1] != '0' for r in results), 'rawTrace': 'upstream-' + family + '.trace.jsonl'}
(evidence / 'upstream-subset.json').write_text(json.dumps(summary, indent=2))

# Local curl HTTPS with explicit CA and hostname verification; no host CA store.
tls = Path('tls'); tls.mkdir()
(tls / 'openssl.cnf').write_text('[req]\ndistinguished_name=dn\n[dn]\n')
(tls / 'payload').write_text('owned-cmake-tls\n')
(tls / 'server.ext').write_text('subjectAltName=DNS:localhost\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n')
run('tls-ca', [c['openssl'], 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
    '-config', 'openssl.cnf', '-keyout', 'ca-key.pem', '-out', 'ca.pem', '-days', '1',
    '-subj', '/CN=Owned CMake local CA', '-addext', 'basicConstraints=critical,CA:TRUE'], cwd=tls)
run('tls-server-csr', [c['openssl'], 'req', '-new', '-newkey', 'rsa:2048', '-nodes',
    '-config', 'openssl.cnf', '-keyout', 'key.pem', '-out', 'server.csr', '-subj', '/CN=localhost'], cwd=tls)
run('tls-server-cert', [c['openssl'], 'x509', '-req', '-in', 'server.csr', '-CA', 'ca.pem',
    '-CAkey', 'ca-key.pem', '-CAcreateserial', '-out', 'cert.pem', '-days', '1', '-extfile', 'server.ext'], cwd=tls)
run('tls-other-cert', [c['openssl'], 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
    '-config', 'openssl.cnf', '-keyout', 'other-key.pem', '-out', 'other.pem', '-days', '1', '-subj', '/CN=untrusted'], cwd=tls)
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
with (evidence / 'tls-server.log').open('w') as log:
    server = subprocess.Popen([c['openssl'], 's_server', '-accept', '127.0.0.1:' + str(port),
        '-cert', 'cert.pem', '-key', 'key.pem', '-WWW', '-quiet'], cwd=tls, stdout=log, stderr=log)
    try:
        for _ in range(100):
            if server.poll() is not None: raise RuntimeError('TLS server exited')
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=.1): break
            except OSError: time.sleep(.05)
        else: raise RuntimeError('TLS server never listened')
        for name, host, ca, success in [('trusted', 'localhost', 'ca.pem', True),
                ('untrusted', 'localhost', 'other.pem', False), ('mismatch', '127.0.0.1', 'ca.pem', False)]:
            script = tls / (name + '.cmake')
            script.write_text('file(DOWNLOAD "https://' + host + ':' + str(port) + '/payload" "' + str((tls / (name + '.data')).resolve()) +
                '" TLS_VERIFY ON TLS_CAINFO "' + str((tls / ca).resolve()) + '" STATUS status LOG log)\nmessage(STATUS "${status}\\n${log}")\nlist(GET status 0 code)\nif(NOT code EQUAL 0)\nmessage(FATAL_ERROR "TLS download failed: ${status}")\nendif()\n')
            p = run('tls-' + name, [cmake, '-P', script], env={}, ok=success)
            assert (p.returncode == 0) == success
            if not success: assert 'TLS download failed: 60;' in p.stdout
            if name == 'untrusted': assert 'unable to get local issuer certificate' in p.stdout
            if name == 'mismatch': assert 'does not match ipv4 address 127.0.0.1' in p.stdout
        assert (tls / 'trusted.data').read_text() == 'owned-cmake-tls\n'
    finally:
        server.terminate()
        try: status = server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill(); status = server.wait()
        (evidence / 'tls-server.status').write_text(str(status) + '\n')
public_tls = evidence / 'tls-fixture'; public_tls.mkdir()
for name in ['ca.pem', 'cert.pem', 'other.pem', 'openssl.cnf', 'server.ext', 'trusted.cmake', 'untrusted.cmake', 'mismatch.cmake']:
    shutil.copyfile(tls / name, public_tls / name)
(evidence / 'success.json').write_text(json.dumps({'generators': ['make', 'ninja'], 'ctestPerGenerator': 2,
    'archives': ['TXZ', 'TGZ', 'TBZ2', 'TZST'], 'tls': ['trusted', 'untrusted', 'mismatch'], 'upstream': summary}, indent=2))
