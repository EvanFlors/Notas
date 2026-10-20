"""Cloud Functions gen 2 HTTP handler (runnable locally via functions-framework).

Signature follows the Functions Framework convention: handler(request) where
`request` is a flask.Request. Return a str, dict, or (body, status, headers).
"""
from __future__ import annotations


def handler(request):  # pragma: no cover - trivial
    name = request.args.get("name", "world")
    return {"hello": name}
