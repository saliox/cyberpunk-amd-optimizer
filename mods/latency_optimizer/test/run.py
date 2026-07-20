#!/usr/bin/env python3
"""Simulation headless de LATENCY OPTIMIZER : charge le vrai init.lua dans des
stubs CET, alimente des frametimes synthétiques et vérifie la mesure et
l'application des réglages. Chaque scénario tourne dans un runtime frais."""
import os
import sys

from lupa import LuaRuntime

BASE = os.path.dirname(os.path.abspath(__file__))
INIT = os.path.abspath(os.path.join(BASE, "..", "init.lua"))
HARNESS = open(os.path.join(BASE, "harness.lua"), encoding="utf-8").read()
SCEN = open(os.path.join(BASE, "scenarios.lua"), encoding="utf-8").read()


def new_runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f"INIT_PATH = [[{INIT}]]")
    lua.execute(HARNESS)
    lua.execute(SCEN)
    return lua


count = new_runtime().eval("#SCENARIOS")
passed, failed = 0, []
for i in range(1, count + 1):
    lua = new_runtime()
    name = lua.eval(f"SCENARIOS[{i}].name")
    ok, err = lua.eval(
        f"(function() local ok, err = pcall(SCENARIOS[{i}].fn) return ok, tostring(err) end)()"
    )
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed.append((name, err))
        print(f"  FAIL  {name}\n        -> {err}")

print(f"\n{passed}/{count} scénarios OK")
sys.exit(1 if failed else 0)
