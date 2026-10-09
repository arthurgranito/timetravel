#!/usr/bin/env python3
"""Escolhe um simulador de iPhone disponível no runner e imprime o UDID.

Uso: python3 scripts/pick_simulator.py [trecho-do-nome-preferido]
Pega o runtime iOS mais novo; dentro dele, prefere o nome pedido
(ex.: "iPhone 15 Pro"); senão, o primeiro iPhone disponível.
O nome escolhido vai para o stderr, o UDID para o stdout.
"""
import json
import re
import subprocess
import sys


def runtime_version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        return (0, 0)
    return (int(match.group(1)), int(match.group(2)))


def main():
    preferred = sys.argv[1] if len(sys.argv) > 1 else ""
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
    data = json.loads(raw)
    candidates = []
    for runtime, devices in data.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for device in devices:
            if device.get("isAvailable", True) and device.get("name", "").startswith("iPhone"):
                candidates.append((runtime_version(runtime), device))
    if not candidates:
        sys.exit("Nenhum simulador de iPhone disponível")
    best_version = max(version for version, _ in candidates)
    latest = [device for version, device in candidates if version == best_version]
    choice = latest[0]
    if preferred:
        for device in latest:
            if preferred in device["name"]:
                choice = device
                break
    print("Simulador: %s (iOS %d.%d)" % (choice["name"], best_version[0], best_version[1]), file=sys.stderr)
    print(choice["udid"])


if __name__ == "__main__":
    main()
