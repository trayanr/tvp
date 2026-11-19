"""Download an immutable archive from ordered HTTPS mirrors."""

from http.client import HTTPException
from http.cookiejar import CookieJar
import os
from pathlib import Path
import shutil
import ssl
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, HTTPCookieProcessor, HTTPSHandler, build_opener


class HTTPSRedirects(HTTPRedirectHandler):
    max_redirections = 20

    def redirect_request(self, request, response, code, message, headers, new_url):
        if urlsplit(new_url).scheme != "https":
            raise HTTPError(request.full_url, code, "redirect outside HTTPS", headers, response)
        return super().redirect_request(request, response, code, message, headers, new_url)


def download(opener, url, dest):
    with opener.open(url, timeout=30) as source, dest.open("wb") as output:
        length = source.length
        shutil.copyfileobj(source, output)
        if length is not None and output.tell() != length:
            raise ConnectionError("download ended before the declared content length")


def transient(error):
    if isinstance(error, HTTPError):
        return error.code in {408, 429, 500, 502, 503, 504, 522, 524}
    if isinstance(error, URLError):
        error = error.reason
    return isinstance(error, (TimeoutError, ConnectionError, HTTPException))


def fetch(opener, urls, dest, retries, retry_delay):
    for url in urls:
        for attempt in range(retries + 1):
            print(f"trying {url}", flush=True)
            try:
                download(opener, url, dest)
            except (URLError, TimeoutError, ConnectionError, HTTPException) as error:
                print(str(error), file=sys.stderr, flush=True)
                dest.unlink(missing_ok=True)
                if attempt == retries or not transient(error):
                    break
                time.sleep(retry_delay or min(2**attempt, 600))
            else:
                return
    raise SystemExit("could not download the pinned archive from any mirror")


if __name__ == "__main__":
    certificates, retries, retry_delay, *urls = sys.argv[1:]
    opener = build_opener(
        HTTPSHandler(context=ssl.create_default_context(cafile=certificates)),
        HTTPSRedirects(),
        HTTPCookieProcessor(CookieJar()),
    )
    fetch(opener, urls, Path(os.environ["out"]), int(retries), int(retry_delay))
