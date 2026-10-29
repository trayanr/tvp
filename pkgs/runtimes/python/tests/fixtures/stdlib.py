import decimal, _decimal
import bz2, ctypes, curses, curses.panel, dbm.gnu, dbm.ndbm, hashlib
import lzma, readline, sqlite3, ssl, uuid, zlib
assert ctypes.CDLL(None).strlen(b"tvp") == 3
assert sqlite3.connect(":memory:").execute("select 42").fetchone()[0] == 42
for backend in (dbm.gnu, dbm.ndbm):
    with backend.open(backend.__name__, "n") as db:
        db[b"answer"] = b"42"
    with backend.open(backend.__name__, "r") as db:
        assert db[b"answer"] == b"42"
for module in (bz2, lzma, zlib):
    assert module.decompress(module.compress(b"tvp")) == b"tvp"
assert ssl.create_default_context().verify_mode == ssl.CERT_REQUIRED
assert hashlib.sha256(b"42").hexdigest().startswith("73475")
assert decimal.Decimal("0.1") + decimal.Decimal("0.2") == decimal.Decimal("0.3")
assert uuid.uuid4().version == 4
print("general-purpose")
