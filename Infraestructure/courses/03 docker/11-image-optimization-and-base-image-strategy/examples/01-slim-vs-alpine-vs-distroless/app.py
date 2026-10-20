"""Minimal app to probe the base image."""
import platform
import sys


def main() -> None:
    print(f"python {sys.version.split()[0]} on {platform.libc_ver()}")
    # Import cryptography to force a native extension actually loads.
    try:
        from cryptography.hazmat.primitives import hashes  # noqa: F401

        print("cryptography: import OK")
    except Exception as exc:  # pragma: no cover
        print(f"cryptography: FAIL ({exc})")
        sys.exit(1)
    print("ok")


if __name__ == "__main__":
    main()
