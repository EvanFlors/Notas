"""Tiny FastAPI-like app surrogate (no server, just imports)."""
from cryptography.hazmat.primitives import hashes  # noqa: F401


def main() -> None:
    print("ok")


if __name__ == "__main__":
    main()
