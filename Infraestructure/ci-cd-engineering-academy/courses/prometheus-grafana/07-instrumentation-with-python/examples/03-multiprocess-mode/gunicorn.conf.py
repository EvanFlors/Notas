"""Gunicorn config for multiprocess prometheus_client.

Hook child_exit so each dying worker's .db files get marked dead
(prevents stale samples lingering forever).
"""

from prometheus_client import multiprocess


def child_exit(server, worker):  # noqa: D401, ARG001
    multiprocess.mark_process_dead(worker.pid)
