#!/usr/bin/env python3
import socket, os, threading
from pathlib import Path

STATE_PATH = Path("/tmp/bitpix-state.json")
SOCK_PATH = "/tmp/bitpix.sock"

def write_state(action: str):
    STATE_PATH.write_text(f"action={action}\n")

def handle_client(conn):
    try:
        data = conn.recv(1024).decode().strip().lower()
        cmd, *_ = data.split()
        if cmd in ("idle", "working", "error", "deploying"):
            write_state(cmd)
            conn.sendall(f"ok state={cmd}\n".encode())
        elif cmd == "status":
            state = STATE_PATH.read_text() if STATE_PATH.exists() else "missing"
            conn.sendall(state.encode())
        else:
            conn.sendall(b"error unknown command\n")
    except Exception as e:
        try:
            conn.sendall(f"error {e}\n".encode())
        except Exception:
            pass
    finally:
        conn.close()

def server():
    if os.path.exists(SOCK_PATH):
        os.remove(SOCK_PATH)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK_PATH)
    os.chmod(SOCK_PATH, 0o666)
    srv.listen(5)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()

if __name__ == "__main__":
    if not STATE_PATH.exists():
        write_state("idle")
    print("BitPix daemon listening on", SOCK_PATH)
    server()
