#!/usr/bin/env bash
# Expérience SIMU, étape 2 : monte un espace neuf et lance le calcul du twin direct de Point034. À refaire à chaque
# exécution : un espace ne sert qu'à un seul calcul.
#
#     bash 2_monter_et_lancer.sh m1-a                  # premier Mac
#     bash 2_monter_et_lancer.sh m1-b                  # second Mac : compare à m1-a
#     bash 2_monter_et_lancer.sh m1-a --ssh            # accès GitHub en SSH (HTTPS par défaut)
#     bash 2_monter_et_lancer.sh m1-a --sans-push      # n'envoie rien dans SIMU
#
# Prérequis : 1_installer_mac.sh déjà passé sur ce Mac.
# Variables : CGS_PATH (dossier des espaces, ~/.cgs par défaut), CGITSYNC_HOME (~/tools/ComplexGitSync par défaut).
# Codes de sortie : 0 identique ou aucune autre machine, 1 au moins une machine DIFFÉRENTE, 2 refus avant le calcul.

set -euo pipefail
export PATH="$HOME/.pixi/bin:$PATH"

AIDE="$(dirname "$0")"
MACHINE="${1:-}"
PROTO="https"
PUSH=1
for arg in "${@:2}"; do
    case "$arg" in
        --ssh) PROTO="ssh" ;;
        --sans-push) PUSH=0 ;;
        *) echo "Option inconnue : $arg" >&2; exit 2 ;;
    esac
done
refuse() { echo "REFUS : $*" >&2; exit 2; }

[[ "$MACHINE" =~ ^[A-Za-z0-9._-]+$ ]] || refuse "donnez un nom de machine (lettres, chiffres, . _ -), par exemple : bash 2_monter_et_lancer.sh m1-a"
[ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ] || refuse "il faut un Mac Apple Silicon."
command -v pixi > /dev/null || refuse "pixi est absent : lancez d'abord 1_installer_mac.sh."
CGS_PATH="${CGS_PATH:-$HOME/.cgs}"
CGITSYNC_HOME="${CGITSYNC_HOME:-$HOME/tools/ComplexGitSync}"
[ -d "$CGITSYNC_HOME" ] || refuse "ComplexGitSync est absent de $CGITSYNC_HOME : lancez d'abord 1_installer_mac.sh."
NOM="simu-$MACHINE"
SPACE="$CGS_PATH/$NOM"
[ ! -e "$SPACE" ] || refuse "$SPACE existe déjà : un espace ne sert qu'à un calcul. Choisissez un autre nom de machine, ou supprimez-le (rm -rf $SPACE)."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "=== Fichier de montage"
curl -fsSL -o "$TMP/simu-direct.cgs" https://raw.githubusercontent.com/flipoyo/MOLONARI1D/CGS-MOLO/simu-direct.cgs
grep -c repository "$TMP/simu-direct.cgs" | sed 's/^/dépôts déclarés : /'

echo "=== Montage de l'espace $SPACE (environ 70 s)"
mkdir -p "$CGS_PATH"
FORCE=()
[ "$PROTO" = "https" ] && FORCE=(--force-protocol https)
(cd "$CGITSYNC_HOME" && pixi run cgitsync bootstrap --cgs-path "$CGS_PATH" ${FORCE[@]+"${FORCE[@]}"} "$TMP/simu-direct.cgs" "$NOM") > "$TMP/bootstrap.log" 2>&1 \
    || { tail -20 "$TMP/bootstrap.log" >&2; refuse "le montage a échoué (journal ci-dessus)."; }
grep -E '^READY' "$TMP/bootstrap.log" | sed 's# root=.*##'
[ -d "$SPACE/SIMU/.git" ] || refuse "l'espace monté ne contient pas SIMU."

echo "=== Alignement sur les commits des machines déjà présentes"
bash "$AIDE/3_aligner_commits.sh" "$SPACE"

echo "=== Dépôts de l'espace"
for d in . Molonaviz data MOLONARI-TWIN SIMU; do
    printf '  %-15s %s\n' "$d" "$(git -C "$SPACE/$d" rev-parse --short HEAD)"
done
[ -z "$(git -C "$SPACE" status --porcelain)" ] || refuse "la racine de l'espace n'est pas propre."

echo "=== Calcul (environ 1 minute)"
cd "$SPACE"
CODE=0
MACHINE="$MACHINE" SIMU_PUSH="$PUSH" pixi run -e simu simu-direct || CODE=$?
echo
case "$CODE" in
    0) echo "Résultat : identique, ou aucune autre machine à comparer." ;;
    1) echo "Résultat : DIFFÉRENT d'au moins une machine. Voir $SPACE/SIMU/forward/Point034/$MACHINE/compte_rendu.txt" ;;
    *) echo "Résultat : refus ou échec (code $CODE)." ;;
esac
exit "$CODE"
