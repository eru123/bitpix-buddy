#!/usr/bin/env python3
import socket, sys

SOCK = "/tmp/bitpix.sock"
cmd = " ".join(sys.argv[1:]) or "help"
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
s.sendall((cmd + "\n").encode())
print(s.recv(1024).decode(), end="")
s.close()
