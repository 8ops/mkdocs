#!/usr/bin/env python3

import socket
import threading
import select
import argparse
from urllib.parse import urlsplit


BUFFER_SIZE = 64 * 1024
TIMEOUT = 30


def recv_headers(client):
    data = b""

    while b"\r\n\r\n" not in data:
        chunk = client.recv(4096)

        if not chunk:
            break

        data += chunk

        if len(data) > 1024 * 1024:
            raise ValueError("HTTP headers too large")

    return data


def tunnel(client, target):
    client.settimeout(TIMEOUT)
    target.settimeout(TIMEOUT)

    sockets = [client, target]

    while True:
        readable, _, exceptional = select.select(
            sockets,
            [],
            sockets,
            TIMEOUT
        )

        if exceptional or not readable:
            break

        for sock in readable:
            try:
                data = sock.recv(BUFFER_SIZE)

                if not data:
                    return

                if sock is client:
                    target.sendall(data)
                else:
                    client.sendall(data)

            except (socket.timeout, ConnectionResetError, BrokenPipeError):
                return


def handle_client(client, addr):
    target = None

    try:
        request = recv_headers(client)

        if not request:
            return

        header_end = request.find(b"\r\n\r\n")

        if header_end == -1:
            return

        header_data = request[:header_end + 4]
        remaining_data = request[header_end + 4:]

        lines = header_data.decode("iso-8859-1").split("\r\n")

        if not lines:
            return

        request_line = lines[0]

        parts = request_line.split()

        if len(parts) < 3:
            client.sendall(
                b"HTTP/1.1 400 Bad Request\r\n"
                b"Content-Length: 0\r\n"
                b"Connection: close\r\n\r\n"
            )
            return

        method = parts[0]
        url = parts[1]
        version = parts[2]

        # ============================================================
        # HTTPS CONNECT
        # ============================================================

        if method.upper() == "CONNECT":

            if ":" in url:
                host, port = url.rsplit(":", 1)
                port = int(port)
            else:
                host = url
                port = 443

            print(
                f"[CONNECT] {addr[0]}:{addr[1]} -> "
                f"{host}:{port}",
                flush=True
            )

            target = socket.create_connection(
                (host, port),
                timeout=TIMEOUT
            )

            client.sendall(
                b"HTTP/1.1 200 Connection Established\r\n"
                b"Proxy-Agent: Python-Stdlib-Proxy\r\n"
                b"\r\n"
            )

            tunnel(client, target)

            return

        # ============================================================
        # HTTP Proxy
        # ============================================================

        parsed = urlsplit(url)

        if parsed.scheme not in ("http", ""):
            client.sendall(
                b"HTTP/1.1 400 Bad Request\r\n"
                b"Content-Length: 0\r\n"
                b"Connection: close\r\n\r\n"
            )
            return

        if parsed.hostname:
            host = parsed.hostname
            port = parsed.port or 80
            path = parsed.path or "/"

            if parsed.query:
                path += "?" + parsed.query

        else:
            # 兼容非 Proxy 格式请求
            host = None
            port = 80
            path = url

            for line in lines[1:]:
                if line.lower().startswith("host:"):
                    host_value = line[5:].strip()

                    if ":" in host_value:
                        host, port_str = host_value.rsplit(":", 1)
                        port = int(port_str)
                    else:
                        host = host_value

                    break

            if not host:
                raise ValueError("Host header not found")

        print(
            f"[{method}] {addr[0]}:{addr[1]} -> "
            f"{host}:{port}{path}",
            flush=True
        )

        target = socket.create_connection(
            (host, port),
            timeout=TIMEOUT
        )

        # ============================================================
        # 修改 Proxy Request
        #
        # GET http://example.com/test
        #
        # 转换成
        #
        # GET /test
        # ============================================================

        new_lines = []

        new_lines.append(
            f"{method} {path} {version}"
        )

        has_host = False

        for line in lines[1:]:

            if not line:
                continue

            lower = line.lower()

            if lower.startswith("proxy-connection:"):
                continue

            if lower.startswith("connection:"):
                continue

            if lower.startswith("host:"):
                has_host = True

            new_lines.append(line)

        if not has_host:
            if port == 80:
                new_lines.append(f"Host: {host}")
            else:
                new_lines.append(f"Host: {host}:{port}")

        new_lines.append("Connection: close")

        new_request = (
            "\r\n".join(new_lines)
            + "\r\n\r\n"
        ).encode("iso-8859-1")

        target.sendall(new_request)

        if remaining_data:
            target.sendall(remaining_data)

        # HTTP response
        while True:
            data = target.recv(BUFFER_SIZE)

            if not data:
                break

            client.sendall(data)

    except Exception as e:

        print(
            f"[ERROR] {addr[0]}:{addr[1]} - {e}",
            flush=True
        )

        try:
            client.sendall(
                b"HTTP/1.1 502 Bad Gateway\r\n"
                b"Content-Length: 0\r\n"
                b"Connection: close\r\n\r\n"
            )
        except Exception:
            pass

    finally:

        try:
            client.close()
        except Exception:
            pass

        if target:
            try:
                target.close()
            except Exception:
                pass


def main():

    parser = argparse.ArgumentParser(
        description="Python Standard Library HTTP/HTTPS Proxy"
    )

    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="Listen address"
    )

    parser.add_argument(
        "--port",
        type=int,
        default=8888,
        help="Listen port"
    )

    args = parser.parse_args()

    server = socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM
    )

    server.setsockopt(
        socket.SOL_SOCKET,
        socket.SO_REUSEADDR,
        1
    )

    server.bind(
        (args.host, args.port)
    )

    server.listen(128)

    print(
        f"HTTP Proxy listening on "
        f"{args.host}:{args.port}",
        flush=True
    )

    try:

        while True:

            client, addr = server.accept()

            thread = threading.Thread(
                target=handle_client,
                args=(client, addr),
                daemon=True
            )

            thread.start()

    except KeyboardInterrupt:

        print("\nProxy stopped")

    finally:

        server.close()


if __name__ == "__main__":
    main()
