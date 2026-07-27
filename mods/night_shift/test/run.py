#!/usr/bin/env python3
"""Simulation headless de NIGHT SHIFT : les stubs CET/Codeware sont partagés
avec la suite SURTENSION ; chaque scénario tourne dans un runtime + dossier
frais. Un pilote autoplay termine chaque mission via l'API publique."""
import os
import sys
import tempfile

from lupa import LuaRuntime

BASE = os.path.dirname(os.path.abspath(__file__))
INIT = os.path.abspath(os.path.join(BASE, "..", "init.lua"))
STUBS_PATH = os.path.abspath(os.path.join(BASE, "..", "..", "surtension", "test", "stubs.lua"))
STUBS = open(STUBS_PATH, encoding="utf-8").read()
SCEN = open(os.path.join(BASE, "scenarios.lua"), encoding="utf-8").read()


def new_runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f"INIT_PATH = [[{INIT}]]")
    lua.execute(STUBS)
    lua.execute(SCEN)
    return lua


count = new_runtime().eval("#SCENARIOS")
passed, failed = 0, []
for i in range(1, count + 1):
    workdir = tempfile.mkdtemp(prefix="nightshift-sim-")
    os.chdir(workdir)
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
