import signal
import sys
import time
import os


def handler(signum, frame):
    name = signal.Signals(signum).name
    print(f"[{os.getpid()}] recibi {name}; shutdown ordenado.", flush=True)
    sys.exit(0)


signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)

print(f"[{os.getpid()}] PID {os.getpid()}; esperando senales...", flush=True)
while True:
    time.sleep(1)
