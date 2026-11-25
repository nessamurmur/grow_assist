"""HEAD a static file, then GET / on the same HTTP/1.1 connection."""

import socket
import sys


def read_headers(sock):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = sock.recv(4096)
        if not chunk:
            sys.stderr.write("socket closed before headers: " + repr(data[:120]) + "\n")
            sys.exit(1)
        data += chunk
    head, _, rest = data.partition(b"\r\n\r\n")
    return head, rest


def content_length(head):
    for line in head.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            return int(line.split(b":", 1)[1].strip())
    return None


def read_body(sock, rest, length):
    while len(rest) < length:
        chunk = sock.recv(8192)
        if not chunk:
            break
        rest += chunk
    return rest


port = int(sys.argv[1])
sock = socket.create_connection(("127.0.0.1", port), timeout=2)
try:
    sock.settimeout(2)
    sock.sendall(
        b"HEAD /static/styles.css HTTP/1.1\r\n"
        b"Host: localhost\r\n"
        b"Connection: keep-alive\r\n"
        b"\r\n"
    )
    head, rest = read_headers(sock)
    if not head.startswith(b"HTTP/1.1 200"):
        sys.stderr.write("HEAD status: " + repr(head[:80]) + "\n")
        sys.exit(1)
    if content_length(head) is None:
        sys.stderr.write("HEAD missing content-length\n" + head.decode() + "\n")
        sys.exit(1)
    if rest:
        sys.stderr.write("HEAD body leaked: " + repr(rest[:80]) + "\n")
        sys.exit(1)
    sock.settimeout(0.3)
    try:
        extra = sock.recv(4096)
    except socket.timeout:
        extra = b""
    if extra:
        sys.stderr.write("HEAD body arrived late: " + repr(extra[:80]) + "\n")
        sys.exit(1)

    sock.settimeout(2)
    sock.sendall(
        b"GET / HTTP/1.1\r\n"
        b"Host: localhost\r\n"
        b"Connection: keep-alive\r\n"
        b"\r\n"
    )
    get_head, get_rest = read_headers(sock)
    if not get_head.startswith(b"HTTP/1.1 200"):
        sys.stderr.write("GET did not start a response: " + repr(get_head[:120]) + "\n")
        sys.exit(1)
    length = content_length(get_head)
    if length is None:
        sys.stderr.write("GET missing content-length\n")
        sys.exit(1)
    get_body = read_body(sock, get_rest, length)
    if b"Grow Assist" not in get_body:
        sys.stderr.write("GET missing shell\n")
        sys.exit(1)
    if b"margin: 0" in get_body[:40]:
        sys.stderr.write("GET body looks like CSS\n")
        sys.exit(1)
    print("ok")
finally:
    sock.close()
