"""Minimal app that exercises a C-extension dependency (msgpack).

msgpack has a native .so built against glibc — on Alpine (musl) you'd see
either slower pure-python fallback or a build-from-source. On distroless
(glibc) the wheel just loads.
"""
import msgpack


def main() -> None:
    payload = msgpack.packb({"hello": "world"})
    assert msgpack.unpackb(payload) == {"hello": "world"}
    print("ok")


if __name__ == "__main__":
    main()
