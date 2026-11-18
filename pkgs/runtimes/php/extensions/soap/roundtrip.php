<?php
final class EchoService
{
    public function echoText(string $value): string
    {
        return 'SOAP: ' . $value;
    }
}

final class InProcessClient extends SoapClient
{
    public function __construct(private SoapServer $server, array $options)
    {
        parent::__construct(null, $options);
    }

    public function __doRequest($request, $location, $action, $version, $oneWay = false, ...$extra): ?string
    {
        ob_start();
        try {
            $this->server->handle($request);
            return ob_get_contents();
        } finally {
            ob_end_clean();
        }
    }
}

$uri = 'urn:tvp:soap';
$server = new SoapServer(null, ['uri' => $uri]);
$server->setClass(EchoService::class);
$client = new InProcessClient($server, ['uri' => $uri, 'location' => $uri]);
echo $client->__soapCall('echoText', ['<&>']);
