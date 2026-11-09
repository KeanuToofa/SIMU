#!/usr/bin/env bash
# Expérience SIMU : aligne les dépôts d'un espace monté sur les commits d'une machine déjà présente dans SIMU.
# Les deux Mac doivent calculer avec exactement les mêmes commits ; sinon `simu-direct` refuse de partir.
# Lancé automatiquement par 2_monter_et_lancer.sh ; peut aussi l'être à la main :
#
#     bash 3_aligner_commits.sh ~/.cgs/simu-m1-b
#
# Aucune autre machine dans SIMU : rien à faire. Les dépôts alignés restent propres (tête détachée).

set -euo pipefail

SPACE="${1:?usage : 3_aligner_commits.sh <espace monté>}"
FORWARD="$SPACE/SIMU/forward/Point034"
REF="$(ls -1 "$FORWARD"/*/commits.json 2> /dev/null | head -1 || true)"
if [ -z "$REF" ]; then
    echo "Aucune autre machine dans SIMU : rien à aligner."
    exit 0
fi
echo "Commits de référence : $REF"
python3 - "$REF" "$SPACE" <<'PYEOF'
import json
import subprocess
import sys

ref, space = sys.argv[1:]
data = json.load(open(ref, encoding="utf-8"))
repos = {"MOLONARI1D": ".", "Molonaviz": "Molonaviz", "data": "data", "MOLONARI-TWIN": "MOLONARI-TWIN"}


def git(path, *args, check=True):
    return subprocess.run(["git", "-C", path, *args], check=check, capture_output=True, text=True)


for name, directory in repos.items():
    path = f"{space}/{directory}"
    want = data[name]["commit"]
    have = git(path, "rev-parse", "HEAD").stdout.strip()
    if have == want:
        print(f"  {name} : déjà à {want[:7]}")
        continue
    if git(path, "cat-file", "-e", f"{want}^{{commit}}", check=False).returncode != 0:
        git(path, "fetch", "--quiet", "origin")
    git(path, "checkout", "--quiet", want)
    print(f"  {name} : {have[:7]} -> {want[:7]}")
PYEOF
