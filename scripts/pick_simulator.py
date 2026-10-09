#!/usr/bin/env python3
"""Escolhe um simulador de iPhone disponível no runner e imprime o UDID.

Uso:
    python3 scripts/pick_simulator.py [trecho-do-nome] [--strict] [--create]

Pega o runtime iOS mais novo; dentro dele, prefere o aparelho cujo nome contém o
trecho pedido (o de nome mais curto, ex.: "Pro" -> "iPhone 17 Pro", não o Pro Max).
Sem --strict, cai para o primeiro iPhone disponível. Com --strict, falha se não achar.
Com --create, se não achar, tenta criar um simulador de um tipo de aparelho cujo
nome contenha o trecho (ex.: "SE") no runtime mais novo.
O nome escolhido vai para o stderr, o UDID para o stdout.
"""
import json
import re
import subprocess
import sys


def runtime_version(identifier):
    match = re.search(r"iOS-(\d+)-(\d+)", identifier)
    if not match:
        return (0, 0)
    return (int(match.group(1)), int(match.group(2)))


def simctl_json(*args):
    raw = subprocess.check_output(["xcrun", "simctl", "list", *args, "-j"])
    return json.loads(raw)


def iphones():
    data = simctl_json("devices", "available")
    found = []
    for runtime, devices in data.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for device in devices:
            if device.get("isAvailable", True) and device.get("name", "").startswith("iPhone"):
                found.append((runtime_version(runtime), device))
    return found


def create(preferred):
    types = simctl_json("devicetypes").get("devicetypes", [])
    runtimes = [r for r in simctl_json("runtimes").get("runtimes", [])
                if r.get("isAvailable", True) and "iOS" in r.get("identifier", "")]
    if not runtimes:
        return None
    runtimes.sort(key=lambda r: runtime_version(r["identifier"]), reverse=True)
    matching = [t for t in types if t.get("name", "").startswith("iPhone") and preferred in t.get("name", "")]
    matching.sort(key=lambda t: t["name"], reverse=True)
    for runtime in runtimes:
        for device_type in matching:
            name = "%s (CI)" % device_type["name"]
            result = subprocess.run(
                ["xcrun", "simctl", "create", name, device_type["identifier"], runtime["identifier"]],
                capture_output=True, text=True)
            if result.returncode == 0:
                print("Simulador criado: %s (%s)" % (name, runtime["identifier"]), file=sys.stderr)
                return result.stdout.strip()
    return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    strict = "--strict" in sys.argv
    allow_create = "--create" in sys.argv
    preferred = args[0] if args else ""

    candidates = iphones()
    if not candidates:
        sys.exit("Nenhum simulador de iPhone disponível")
    best_version = max(version for version, _ in candidates)
    latest = [device for version, device in candidates if version == best_version]

    if preferred:
        matches = sorted((d for d in latest if preferred in d["name"]), key=lambda d: len(d["name"]))
        if not matches:
            matches = sorted((d for _, d in candidates if preferred in d["name"]), key=lambda d: len(d["name"]))
        if matches:
            choice = matches[0]
            print("Simulador: %s" % choice["name"], file=sys.stderr)
            print(choice["udid"])
            return
        if allow_create:
            udid = create(preferred)
            if udid:
                print(udid)
                return
        if strict:
            sys.exit("Nenhum simulador com '%s' no nome" % preferred)

    choice = latest[0]
    print("Simulador: %s (iOS %d.%d)" % (choice["name"], best_version[0], best_version[1]), file=sys.stderr)
    print(choice["udid"])


if __name__ == "__main__":
    main()
