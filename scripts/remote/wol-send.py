#!/usr/bin/env python3
"""Envoie un Magic Packet Wake-on-LAN (bibliothèque standard uniquement).

À exécuter sur le relais toujours allumé du réseau local (Raspberry Pi, NAS, mini-PC, routeur
compatible), jamais sur le PC à réveiller : un PC éteint n'exécute rien.
"""
import argparse
import ipaddress
import re
import socket
import sys
import time

MAC_PATTERN = re.compile(r"^(?:[0-9A-Fa-f]{2}([:-]))(?:[0-9A-Fa-f]{2}\1){4}[0-9A-Fa-f]{2}$|^[0-9A-Fa-f]{12}$")


def parse_mac(text: str) -> bytes:
    if not MAC_PATTERN.match(text):
        raise ValueError(f"adresse MAC invalide : {text!r}")
    return bytes.fromhex(re.sub(r"[:-]", "", text))


def magic_packet(mac: bytes) -> bytes:
    if len(mac) != 6:
        raise ValueError("une adresse MAC fait 6 octets")
    return b"\xff" * 6 + mac * 16


def parse_broadcast(text: str) -> str:
    address = ipaddress.ip_address(text)
    if address.version != 4:
        raise ValueError("seule l'adresse de diffusion IPv4 est supportée")
    return str(address)


def send(packet: bytes, broadcast: str, port: int, repeat: int, interval: float) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        for index in range(repeat):
            sock.sendto(packet, (broadcast, port))
            if index + 1 < repeat:
                time.sleep(interval)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("mac", help="adresse MAC de l'Ethernet du PC (aa:bb:cc:dd:ee:ff)")
    parser.add_argument("--broadcast", default="255.255.255.255", help="adresse de diffusion du LAN (ex. 192.168.1.255)")
    parser.add_argument("--port", type=int, default=9, help="port UDP (9 par défaut, 7 possible)")
    parser.add_argument("--repeat", type=int, default=3, help="nombre d'envois (robustesse)")
    parser.add_argument("--interval", type=float, default=0.3, help="secondes entre deux envois")
    parser.add_argument("--print-packet", action="store_true", help="affiche le paquet en hexadécimal sans l'envoyer")
    args = parser.parse_args(argv)
    try:
        packet = magic_packet(parse_mac(args.mac))
        broadcast = parse_broadcast(args.broadcast)
    except ValueError as error:
        print(f"ERREUR : {error}", file=sys.stderr)
        return 2
    if not 1 <= args.port <= 65535 or not 1 <= args.repeat <= 10:
        print("ERREUR : port ou nombre d'envois hors limites", file=sys.stderr)
        return 2
    if args.print_packet:
        print(packet.hex())
        return 0
    send(packet, broadcast, args.port, args.repeat, args.interval)
    print(f"Magic Packet envoyé vers {broadcast}:{args.port} pour {args.mac} ({args.repeat} fois)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
