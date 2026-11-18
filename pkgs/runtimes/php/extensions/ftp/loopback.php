<?php

function exchange($peer, string $request, string $response): void
{
    $line = fgets($peer);
    if ($line !== "$request\r\n") {
        throw new RuntimeException("Expected $request, received " . var_export($line, true));
    }
    fwrite($peer, "$response\r\n");
}

// Use the fixture's own control connection and upgrade it after AUTH TLS.
if ($argv[1] === '--server') {
    $context = stream_context_create(['ssl' => [
        'local_cert' => getcwd() . '/cert.pem',
        'local_pk' => getcwd() . '/key.pem',
    ]]);
    $listener = stream_socket_server('tcp://127.0.0.1:0', $errno, $error, STREAM_SERVER_BIND | STREAM_SERVER_LISTEN, $context);
    if ($listener === false) {
        throw new RuntimeException("FTP listener failed: $error");
    }
    echo stream_socket_get_name($listener, false), "\n";
    fflush(STDOUT);

    $peer = stream_socket_accept($listener, 10);
    if ($peer === false) {
        throw new RuntimeException('FTP fixture did not receive a client');
    }
    stream_set_timeout($peer, 10);
    fwrite($peer, "220 TVP FTP fixture\r\n");
    exchange($peer, 'AUTH TLS', '234 Start TLS');
    if (stream_socket_enable_crypto($peer, true, STREAM_CRYPTO_METHOD_TLS_SERVER) !== true) {
        throw new RuntimeException('FTP fixture TLS handshake failed');
    }
    exchange($peer, 'PBSZ 0', '200 Buffer size set');
    exchange($peer, 'PROT P', '200 Data protection set');
    exchange($peer, 'USER fixture', '331 Password required');
    exchange($peer, 'PASS fixture', '230 Logged in');
    exchange($peer, 'NOOP', '200 TVP FTPS fixture');
    exchange($peer, 'QUIT', '221 Goodbye');
    fclose($peer);
    exit(0);
}

$server = proc_open([$argv[1], __FILE__, '--server'], [1 => ['pipe', 'w']], $pipes);
if ($server === false) {
    throw new RuntimeException('Could not start FTP fixture');
}
try {
    stream_set_timeout($pipes[1], 10);
    $address = fgets($pipes[1]);
    if ($address === false || !preg_match('/^127\.0\.0\.1:([0-9]+)\n$/', $address, $match)) {
        throw new RuntimeException('FTP fixture did not publish a loopback port');
    }
    $ftp = ftp_ssl_connect('127.0.0.1', (int) $match[1], 10);
    if ($ftp === false || !ftp_login($ftp, 'fixture', 'fixture')) {
        throw new RuntimeException('Could not log in over FTP TLS');
    }
    $reply = ftp_raw($ftp, 'NOOP');
    if (!ftp_close($ftp) || $reply !== ['200 TVP FTPS fixture']) {
        throw new RuntimeException('Unexpected FTP control response');
    }
} finally {
    fclose($pipes[1]);
    $status = proc_close($server);
}
if ($status !== 0) {
    throw new RuntimeException("FTP fixture exited with status $status");
}
echo $reply[0];
