#!/usr/bin/env bash
# Expérience SIMU, étape 1 : installe ce qu'il faut sur un Mac M1, une seule fois. Sans danger si on le relance :
# ce qui est déjà en place n'est pas touché.
#
#     bash 1_installer_mac.sh                 # accès GitHub en HTTPS (gh auth login dans le navigateur)
#     bash 1_installer_mac.sh --ssh           # accès GitHub en SSH (clé déjà déclarée sur le compte)
#
# Variables facultatives : GIT_NOM et GIT_EMAIL (sinon le script les demande si git n'est pas configuré).
# Installe, si absents : pixi 0.81.0, gh, ComplexGitSync (8.6.2) dans ~/tools/ComplexGitSync.

set -euo pipefail

PIXI_VERSION_VOULUE="0.81.0"
CGS_URL="https://github.com/flipoyo/ComplexGitSync.git"
CGS_COMMIT="9594d7e"
CGS_DIR="${CGITSYNC_HOME:-$HOME/tools/ComplexGitSync}"
PROTO="https"
[ "${1:-}" = "--ssh" ] && PROTO="ssh"

etape() { echo; echo "=== $*"; }
refuse() { echo "REFUS : $*" >&2; exit 2; }

etape "Machine"
if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    refuse "il faut un Mac Apple Silicon (Darwin arm64), pas $(uname -s) $(uname -m)."
fi
echo "Mac Apple Silicon, macOS $(sw_vers -productVersion)"

etape "git"
if ! command -v git > /dev/null || ! git --version > /dev/null 2>&1; then
    xcode-select --install 2> /dev/null || true
    refuse "git est absent. Acceptez l'installation des outils en ligne de commande qui vient de s'ouvrir, puis relancez ce script."
fi
git --version
if [ -z "$(git config --global user.name || true)" ]; then
    NOM="${GIT_NOM:-}"
    [ -n "$NOM" ] || { [ -t 0 ] && read -r -p "Votre nom pour git : " NOM; }
    [ -n "$NOM" ] || refuse "nom git inconnu : relancez avec GIT_NOM='Votre Nom'."
    git config --global user.name "$NOM"
fi
if [ -z "$(git config --global user.email || true)" ]; then
    MEL="${GIT_EMAIL:-}"
    [ -n "$MEL" ] || { [ -t 0 ] && read -r -p "Votre e-mail pour git : " MEL; }
    [ -n "$MEL" ] || refuse "e-mail git inconnu : relancez avec GIT_EMAIL='vous@exemple.fr'."
    git config --global user.email "$MEL"
fi
echo "git : $(git config --global user.name) <$(git config --global user.email)>"

etape "pixi $PIXI_VERSION_VOULUE"
export PATH="$HOME/.pixi/bin:$PATH"
if ! command -v pixi > /dev/null || [ "$(pixi --version | awk '{print $2}')" != "$PIXI_VERSION_VOULUE" ]; then
    curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION="$PIXI_VERSION_VOULUE" bash
    export PATH="$HOME/.pixi/bin:$PATH"
fi
pixi --version

etape "gh (GitHub CLI) et accès à GitHub ($PROTO)"
if [ "$PROTO" = "https" ]; then
    if ! command -v gh > /dev/null; then
        if command -v brew > /dev/null; then brew install gh; else pixi global install gh; fi
        export PATH="$HOME/.pixi/bin:$PATH"
    fi
    if ! gh auth status > /dev/null 2>&1; then
        echo "Connexion à GitHub : suivez les instructions (compte KeanuToofa ou collaborateur de KeanuToofa/SIMU)."
        gh auth login --hostname github.com --git-protocol https --web
    fi
    if ! git config --global --get-all credential.https://github.com.helper 2> /dev/null | grep -q 'gh auth git-credential'; then
        gh auth setup-git
    fi
    echo "GitHub : connecté en tant que $(gh api user --jq .login)"
else
    set +e
    SSH_REPONSE="$(ssh -o BatchMode=yes -T git@github.com 2>&1)"
    set -e
    case "$SSH_REPONSE" in
        *"successfully authenticated"*) echo "$SSH_REPONSE" ;;
        *) refuse "SSH ne s'authentifie pas auprès de GitHub : $SSH_REPONSE" ;;
    esac
fi

etape "ComplexGitSync dans $CGS_DIR"
if [ ! -d "$CGS_DIR/.git" ]; then
    mkdir -p "$(dirname "$CGS_DIR")"
    git clone "$CGS_URL" "$CGS_DIR"
    git -C "$CGS_DIR" checkout --quiet "$CGS_COMMIT"
else
    echo "déjà présent (commit $(git -C "$CGS_DIR" rev-parse --short HEAD)), non modifié."
fi
if [ ! -x "$CGS_DIR/.pixi/envs/default/bin/cgitsync" ]; then
    (cd "$CGS_DIR" && pixi install)
fi
VERSION="$("$CGS_DIR/.pixi/envs/default/bin/cgitsync" --version)"
echo "$VERSION"
[ "$VERSION" = "cgitsync 8.6.2" ] || echo "ATTENTION : version attendue cgitsync 8.6.2 ; les essais ont été faits avec celle-là."

etape "Terminé"
echo "Étape suivante, dans ce dossier :"
echo "    bash 2_monter_et_lancer.sh m1-a        # nom de la machine : m1-a, m1-b, …"
