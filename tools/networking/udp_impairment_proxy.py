#!/usr/bin/env python3
"""Localhost ENet/UDP impairment proxy for development only.

One client per proxy port. Simulates one-way delay, jitter and packet loss
for actual UDP datagrams including Godot replication traffic.
"""
import argparse
import heapq
import itertools
import random
import select
import socket
import time


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", type=int, default=42070)
    parser.add_argument("--target", type=int, default=42069)
    parser.add_argument("--delay", type=float, default=100.0)
    parser.add_argument("--jitter", type=float, default=0.0)
    parser.add_argument("--loss", type=float, default=0.0)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    if not 0 <= args.loss <= 100 or min(args.delay, args.jitter) < 0:
        parser.error("Loss must be 0-100; delay and jitter must be nonnegative.")
    if not 1 <= args.listen <= 65535 or not 1 <= args.target <= 65535:
        parser.error("UDP ports must be between 1 and 65535.")

    rng = random.Random(args.seed)
    client_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client_sock.bind(("127.0.0.1", args.listen))
    server_sock.bind(("127.0.0.1", 0))
    server_address = ("127.0.0.1", args.target)
    client_address = None
    queue = []
    sequence = itertools.count()
    print(f"ENet proxy 127.0.0.1:{args.listen} -> {server_address}", flush=True)
    try:
        while True:
            now = time.monotonic()
            for source in select.select([client_sock, server_sock], [], [], 0.005)[0]:
                payload, sender = source.recvfrom(65535)
                if source is client_sock:
                    if client_address is not None and sender != client_address:
                        continue
                    client_address = sender
                    output, destination = server_sock, server_address
                else:
                    if client_address is None or sender != server_address:
                        continue
                    output, destination = client_sock, client_address
                if rng.random() * 100 < args.loss:
                    continue
                delay = max(0.0, args.delay + rng.uniform(-args.jitter, args.jitter))
                heapq.heappush(
                    queue,
                    (now + delay / 1000.0, next(sequence), output, destination, payload),
                )
            while queue and queue[0][0] <= time.monotonic():
                _, _, sock, destination, payload = heapq.heappop(queue)
                sock.sendto(payload, destination)
    except KeyboardInterrupt:
        pass
    finally:
        client_sock.close()
        server_sock.close()


if __name__ == "__main__":
    main()
