# Reproductibilité du modèle direct de Point034 sur deux machines

Ce tutoriel fait calculer le **twin direct de Point034** sur deux machines différentes, A et B. On vérifie ensuite que les deux calculs donnent **exactement les mêmes nombres, au bit près**.

Tout se fait à la main, commande par commande, sans script. Il y a trois étapes :

1. installer l'operating space à partir du fichier `simu-direct.cgs` ;
2. lancer le modèle direct avec la CLI `molonari-twin` ;
3. comparer les résultats de A et de B.

La dernière partie explique le **protocole de comparaison** : ce qui est comparé, comment, et ce que le résultat prouve.

Durées mesurées sur un Mac M1 : montage 70 s, préparation des données 13 s, modèle direct 15 s.

---

## Le principe en une figure

```text
      machine A                                   machine B
 ┌──────────────────────┐                  ┌──────────────────────┐
 │ simu-direct.cgs      │                  │ simu-direct.cgs      │
 │   → bootstrap        │                  │   → bootstrap        │
 │   → espace neuf      │   commits.json   │   → espace neuf      │
 │                      │ ───────────────► │   → mêmes commits    │
 │ lab build + run      │                  │ lab build + run      │
 │ reproduce --export A │                  │ reproduce --export B │
 └──────────┬───────────┘                  └──────────┬───────────┘
            │         dépôt SIMU (git push / pull)    │
            └────────────────────►────────────────────┘
                                 reproduce --compare A B
                                   → IDENTIQUE ou DIFFÉRENCES
```

Les deux machines partent du même fichier `.cgs`, aux mêmes commits et avec les mêmes versions de bibliothèques figées. Chacune calcule de son côté et exporte son résultat dans le dépôt `KeanuToofa/SIMU`. B compare ensuite son export à celui de A.

---

## 0. Avant de commencer

### Machines acceptées

| Machine | Possible ? | Remarque |
|---|---|---|
| Mac Apple Silicon (M1, M2…) | oui | macOS, git des outils en ligne de commande |
| Linux x86-64 | oui | glibc 2.27 ou plus (Ubuntu 18.04+, conseillé : Ubuntu 24.04 ou Debian 12) |
| Linux aarch64 | oui | mais ne teste pas x86-64 |
| Mac Intel | **non** | `jaxlib 0.11.2` n'a pas de paquet pour lui |
| Alpine (musl) | **non** | pas de paquet `jaxlib` |

Avec deux Mac M1, on teste « deux machines, même architecture ». Avec un Mac M1 et un Linux x86-64, on teste aussi le changement de processeur.

### Noms à fixer

Dans **chaque nouveau terminal**, sur chaque machine, définir :

```bash
MACHINE=pc-a                              # pc-a sur la machine A, pc-b sur la machine B (lettres, chiffres, . _ -)
ESPACE="$HOME/.cgs/simu-$MACHINE"         # l'operating space monté à l'étape 1
TWIN_CLI="$ESPACE/Molonaviz/molonari_desk/.venv/bin/molonari-twin"
TWIN=MOLONARI-TWIN/Point034/twins/twin_direct
```

### Ordre

**A d'abord, B ensuite.** B a besoin des commits et de l'export de A.

---

## 1. Installer l'operating space à partir du fichier `.cgs`

L'operating space est un dossier qui réunit cinq dépôts git, chacun à sa place. ComplexGitSync (`cgitsync`) le monte d'après la liste du fichier `simu-direct.cgs`. On ne clone rien à la main : tout part de ce fichier.

### 1.1 Outils de base (une fois par machine)

**Sur Mac :**

```bash
git --version          # si absent, macOS propose les outils en ligne de commande : accepter
```

**Sur Linux (Ubuntu, Debian) :**

```bash
sudo apt update && sudo apt install -y curl git python3 ca-certificates
git --version          # il faut 2.39 ou plus ; sinon, après l'étape 1.2 : pixi global install git
```

**Sur les deux :** git doit connaître votre nom, car on fera un commit dans SIMU.

```bash
git config --global user.name  "Votre Nom"
git config --global user.email "vous@exemple.fr"
```

### 1.2 pixi 0.81 (une fois par machine)

```bash
curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION=0.81.0 bash
exec $SHELL                 # recharge le PATH (~/.pixi/bin)
pixi --version              # attendu : pixi 0.81.0
```

`uv` ne s'installe pas à la main : l'environnement `simu` de l'espace le fournit (étape 1.6).

### 1.3 Accès en écriture à GitHub (pour pousser dans SIMU)

Le montage se fait sans compte, car tous les dépôts sont publics. Un accès est seulement nécessaire pour **pousser** l'export dans SIMU. Il faut être le compte `KeanuToofa` ou un collaborateur du dépôt `KeanuToofa/SIMU`.

```bash
pixi global install gh      # ou, sur Mac : brew install gh
gh auth login               # GitHub.com, HTTPS ; sans navigateur : « Paste an authentication token »
gh auth setup-git
gh api user --jq .login     # vérifier le compte
```

Sans accès en écriture, voir la variante « sans GitHub » à l'étape 3.1.

### 1.4 ComplexGitSync 8.8.0 (une fois par machine)

```bash
mkdir -p ~/tools
git clone https://github.com/flipoyo/ComplexGitSync.git ~/tools/ComplexGitSync
cd ~/tools/ComplexGitSync
git checkout 47d4100        # version 8.8.0
pixi install
pixi run cgitsync --version # attendu : cgitsync 8.8.0
```

Si `~/tools/ComplexGitSync` existe déjà, mettre à jour avec `git pull --ff-only origin main && pixi install`, puis vérifier la version.

### 1.5 Récupérer le fichier `.cgs` et monter l'espace (à chaque calcul)

```bash
mkdir -p ~/simu-montage && cd ~/simu-montage
curl -fsSL -o simu-direct.cgs \
  https://raw.githubusercontent.com/flipoyo/MOLONARI1D/WORK-KEANU/simu-direct.cgs
cat simu-direct.cgs
```

Le fichier déclare cinq dépôts :

| Dépôt | Place dans l'espace | Branche | Rôle |
|---|---|---|---|
| `flipoyo/MOLONARI1D` | racine | `WORK-KEANU` | le projet et son `pixi.toml` (environnement `simu`) |
| `flipoyo/MOLONARI-API` | `Molonaviz/` | `CGS-MOLO` | le code : CLI `molonari-twin` et son `uv.lock` |
| `flipoyo/MOLONARI-data` | `data/` | `CGS-MOLO` | les mesures brutes de Point034 |
| `KeanuToofa/MOLONARI-TWIN` | `MOLONARI-TWIN/` | `CGS-MOLO` | le virtual lab et le twin direct (`twin.yaml`) |
| `KeanuToofa/SIMU` | `SIMU/` | `CGS-MOLO` | le dépôt d'échange des exports |

Monter l'espace (environ 70 s) :

```bash
cd ~/tools/ComplexGitSync
pixi run cgitsync bootstrap --cgs-path "$HOME/.cgs" --force-protocol https \
  ~/simu-montage/simu-direct.cgs "simu-$MACHINE"
```

Attendu à la fin : `READY ready=true complete=true`.

**Un espace ne sert qu'à un seul calcul.** Pour recommencer : `rm -rf "$ESPACE"`, puis monter à nouveau.

### 1.6 Vérifier l'espace et figer les versions

```bash
cd "$ESPACE"
for d in . Molonaviz data MOLONARI-TWIN SIMU; do
  printf '%-15s %s  %s modif.\n' "$d" "$(git -C $d rev-parse --short HEAD)" "$(git -C $d status --porcelain | wc -l | tr -d ' ')"
done
```

Attendu : `0 modif.` sur les cinq dépôts.

**Sur B seulement : se placer aux commits de A.** Les branches ont pu avancer entre les deux montages. On replace donc chaque dépôt sur le commit noté par A dans son `commits.json` (écrit à l'étape 2.4) :

```bash
cd "$ESPACE"
git -C SIMU pull --ff-only
python3 - SIMU/forward/Point034/pc-a/commits.json <<'EOF'
import json, subprocess, sys
ref = json.load(open(sys.argv[1]))
for nom, dossier in {"MOLONARI1D": ".", "Molonaviz": "Molonaviz", "data": "data", "MOLONARI-TWIN": "MOLONARI-TWIN"}.items():
    voulu = ref[nom]["commit"]
    actuel = subprocess.run(["git", "-C", dossier, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if actuel != voulu:
        subprocess.run(["git", "-C", dossier, "fetch", "--quiet", "origin"], check=True)
        subprocess.run(["git", "-C", dossier, "checkout", "--quiet", voulu], check=True)
    print(f"{nom:14} {voulu[:7]}  {'replacé' if actuel != voulu else 'déjà bon'}")
EOF
```

**Sur les deux : installer le code aux versions figées.**

```bash
cd "$ESPACE"
pixi run -e simu uv --directory Molonaviz/molonari_desk \
  sync --frozen --package molonari-twin --no-default-groups
"$TWIN_CLI" --help | head -3
```

`--frozen` installe exactement les versions écrites dans `uv.lock` (`jax` et `jaxlib` 0.11.2, `numpy`, etc.), sans rien résoudre de neuf. C'est une condition du protocole (voir la partie 4).

Facultatif : vérifier les outils que demande le `.cgs` (git ≥ 2.39, uv ≥ 0.9, pixi ≥ 0.81).

```bash
pixi run -e simu ~/tools/ComplexGitSync/.pixi/envs/default/bin/cgitsync env check --cgs simu-direct.cgs
# attendu : matches=true (les lignes undeclared=… sont sans importance)
```

---

## 2. Lancer le modèle direct (CLI)

À faire **sur A, puis sur B**, de la même façon.

### 2.1 Préparer les données : le virtual lab

Le modèle direct lit les données traitées de Point034. Le virtual lab les fabrique à partir des mesures brutes de `data/` : nettoyage, dates en UTC.

```bash
cd "$ESPACE"
"$TWIN_CLI" lab build MOLONARI-TWIN/virtual_lab/lab_point034/description --point Point034
```

Attendu :

```text
Données traitées écrites : …/data/processed_data/Point034 (1430 lignes, du 2016-06-27T12:00:00 au 2016-07-12T09:15:00,
empreinte ff9da4d1a9e8cec9e9ecd99d9a9270c1fc5dfd0c4339f27fb1512293de204a70).
```

L'empreinte doit être la même sur A et sur B : c'est la preuve que les deux calculs partent de la même entrée. `git status` montre ensuite `?? processed_data/` dans `data/`. C'est normal : ce dossier n'est pas suivi.

### 2.2 Lancer le modèle direct

Le twin direct résout l'équation de la chaleur et de l'écoulement dans la colonne de Point034, avec les paramètres figés dans `twin.yaml`. Il n'y a pas d'inversion et pas de tirage aléatoire.

```bash
cd "$ESPACE"
ls -A "$TWIN/results" 2> /dev/null       # attendu : rien (le calcul doit avoir lieu dans cet espace)
"$TWIN_CLI" run "$TWIN"
```

Attendu : `twin_direct calculé en … s → MOLONARI-TWIN/Point034/twins/twin_direct/results/<twin_id>`.

Ne pas ajouter `--strict` : cette option refuse un code non tagué, ce qui est le cas ici.

### 2.3 Exporter le résultat

```bash
cd "$ESPACE"
OUT="SIMU/forward/Point034/$MACHINE"
"$TWIN_CLI" reproduce "$TWIN" --export "$OUT"
cat "$OUT/resultats.txt"
```

`reproduce --export` ne recalcule rien. Il écrit dans `$OUT` :

| Fichier | Contenu |
|---|---|
| `results/` | les sept fichiers de résultats : `temperature.csv`, `water_flux.csv`, `water_flux_field.csv`, `heat_flux_advective.csv`, `heat_flux_conductive.csv`, `residuals.csv`, `metadata.json` |
| `fingerprint.json` | l'empreinte SHA-256 de chaque fichier, la « recette » du calcul et la description de la machine |
| `resultats.txt` | les valeurs clés, en décimal et en hexadécimal exact |

Valeurs attendues (Mac M1, code en UTC) :

```text
water_flux_mean = -4.524782784649976e-07 | -0x1.e5d84839271fbp-22
rmse_total = 0.11620092968527289 | 0x1.dbf5818c356c3p-4
```

### 2.4 Noter les commits et la machine

B en aura besoin pour se placer aux mêmes commits (étape 1.6).

```bash
cd "$ESPACE"
python3 - "$OUT/commits.json" "$MACHINE" <<'EOF'
import json, platform, subprocess, sys
cible, machine = sys.argv[1:]
git = lambda d, *a: subprocess.run(["git", "-C", d, *a], capture_output=True, text=True, check=True).stdout.strip()
data = {"machine": machine, "uname": " ".join(platform.uname()), "simu_commit": git("SIMU", "rev-parse", "HEAD")}
for nom, d in {"MOLONARI1D": ".", "Molonaviz": "Molonaviz", "data": "data", "MOLONARI-TWIN": "MOLONARI-TWIN"}.items():
    data[nom] = {"commit": git(d, "rev-parse", "HEAD"), "branch": git(d, "rev-parse", "--abbrev-ref", "HEAD")}
json.dump(data, open(cible, "w"), indent=2, sort_keys=True)
EOF
~/tools/ComplexGitSync/.pixi/envs/default/bin/cgitsync env show > "$OUT/environment.txt" 2>&1
cat "$OUT/commits.json"
```

---

## 3. Comparer les résultats des deux machines

### 3.1 Faire passer l'export de A à B

**Sur A**, déposer l'export dans SIMU :

```bash
cd "$ESPACE"
git -C SIMU pull --ff-only
git -C SIMU add "forward/Point034/$MACHINE"
git -C SIMU commit -m "simu: export de $MACHINE"
git -C SIMU push
```

**Sur B**, l'export de A arrive avec le `git -C SIMU pull --ff-only` de l'étape 1.6. Faire ensuite les étapes 2.1 à 2.4 avec `MACHINE=pc-b`.

**Variante sans GitHub :** copier le dossier `SIMU/forward/Point034/pc-a/` de A (clé USB, `scp`, zip) dans le même chemin sur B, avant l'étape 1.6. Sans commit, SIMU apparaît « modifié » sur B : c'est normal dans ce cas.

### 3.2 Lancer la comparaison (sur B)

```bash
cd "$ESPACE"
"$TWIN_CLI" reproduce --compare SIMU/forward/Point034/pc-a SIMU/forward/Point034/pc-b
echo "code de sortie : $?"
```

Résultat attendu :

```text
======================================================================
Comparaison de deux exports
======================================================================

IDENTIQUE
  heat_flux_advective.csv: ok
  heat_flux_conductive.csv: ok
  metadata.json: ok
  residuals.csv: ok
  temperature.csv: ok
  water_flux.csv: ok
  water_flux_field.csv: ok
======================================================================
code de sortie : 0
```

Garder le détail au format JSON, et comparer les valeurs clés à l'œil :

```bash
"$TWIN_CLI" reproduce --compare SIMU/forward/Point034/pc-a SIMU/forward/Point034/pc-b --json \
  > SIMU/forward/Point034/pc-b/compare_pc-a.json
diff SIMU/forward/Point034/pc-a/resultats.txt SIMU/forward/Point034/pc-b/resultats.txt && echo "valeurs clés identiques"
```

### 3.3 Déposer le résultat (sur B)

```bash
cd "$ESPACE"
echo "pc-a : $("$TWIN_CLI" reproduce --compare SIMU/forward/Point034/pc-a SIMU/forward/Point034/pc-b > /dev/null && echo identique || echo DIFFÉRENT)" \
  > SIMU/forward/Point034/pc-b/compte_rendu.txt
git -C SIMU add forward/Point034/pc-b
git -C SIMU commit -m "simu: export de pc-b"
git -C SIMU push
```

---

## 4. Le protocole de comparaison

### 4.1 Ce qu'on cherche à prouver

Pour une même recette (même code, mêmes données, mêmes paramètres, mêmes versions de bibliothèques), le modèle direct doit donner **les mêmes nombres flottants, bit pour bit**, sur une autre machine montée de zéro. Une simple « faible différence » ne suffit pas : on vise l'égalité exacte.

### 4.2 Les conditions, avant tout calcul

Une comparaison n'a de sens que si les deux calculs ne diffèrent **que par la machine**. Chaque condition du protocole écarte une autre cause d'écart possible :

| Condition | Comment elle est garantie | Ce qu'elle écarte |
|---|---|---|
| Même description de l'espace | le même fichier `simu-direct.cgs`, monté par `cgitsync bootstrap` | un dépôt oublié, un chemin différent |
| Mêmes commits | B se place sur les commits du `commits.json` de A (étape 1.6) | un code, des données ou un twin qui ont changé entre-temps |
| Mêmes versions de bibliothèques | `uv sync --frozen` sur le même `uv.lock` | une autre version de `jax`, `jaxlib` ou `numpy` |
| Espace neuf, dépôts propres | `bootstrap` dans un dossier neuf, `0 modif.` à l'étape 1.6 | un fichier modifié à la main, un ancien résultat réutilisé |
| Calcul sur place | `results/` vide avant `run` (étape 2.2) | un résultat recopié au lieu d'être recalculé |
| Même entrée | même empreinte affichée par `lab build` (`ff9da4d1…`) | des données nettoyées autrement |

### 4.3 Ce que compare `reproduce --compare`

La commande lit les deux dossiers d'export et fait trois contrôles. **Les trois doivent passer** pour afficher `IDENTIQUE`.

**1. Les fichiers de résultats, un par un.** La commande compare l'empreinte SHA-256 de chaque fichier de `results/`. Une empreinte égale veut dire un fichier identique octet pour octet. Un fichier présent d'un seul côté est une différence.

Pourquoi l'égalité des CSV vaut l'égalité des nombres : les résultats sont écrits au format `%.17g`, soit 17 chiffres significatifs. C'est assez pour qu'un nombre `float64` relu redonne exactement le même nombre. Deux CSV identiques octet pour octet contiennent donc les mêmes flottants au bit près. À l'inverse, le moindre écart sur le dernier bit change le texte, donc l'empreinte.

**2. Les métadonnées, sans ce qui dépend de l'instant.** `metadata.json` n'est pas comparé octet pour octet. On retire d'abord trois champs qui changent forcément d'une machine à l'autre : `created_at` (date du calcul), `duration_s` (durée) et `provenance` (chemins, machine). On compare ensuite l'empreinte du reste, écrit sous une forme canonique (clés triées). Tout le reste doit être égal : paramètres, RMSE, version du format, etc.

**3. La recette du calcul.** Dans `fingerprint.json`, ces champs doivent être égaux des deux côtés :

| Champ | Sens |
|---|---|
| `twin_id` | empreinte de la configuration du twin : paramètres, empreinte des mesures nettoyées, version du code |
| `engine_version` | version du moteur de calcul |
| `jax`, `jaxlib`, `numpy` | versions des bibliothèques réellement chargées |
| `cleaned_sha256` | empreinte des données traitées par le virtual lab |

Une différence ici s'affiche `recette différente : <champ>`. Cela veut dire qu'on n'a pas fait deux fois le même calcul. Ce n'est donc pas un défaut de reproductibilité, mais un défaut de protocole (conditions de la partie 4.2).

**Ce qui est volontairement ignoré :** `platform` (système, version, processeur) et `device` (CPU ou GPU). C'est justement ce qui change d'une machine à l'autre.

### 4.4 Lire le résultat

| Affichage | Code | Sens |
|---|---|---|
| `IDENTIQUE` | 0 | les sept fichiers sont égaux au bit, et la recette est la même |
| `DIFFERENCES DETECTEES` + `DIFFERENT (empreintes SHA-256 différentes)` | 1 | même recette, mais des nombres différents : écart de reproductibilité |
| `DIFFERENCES DETECTEES` + `recette différente : …` | 1 | ce ne sont pas les mêmes calculs : revoir commits, `uv sync --frozen` et `lab build` |
| `metadata.json: DIFFERENT (métadonnées comparables différentes…)` | 1 | un paramètre ou une valeur résumée diffère |

En cas d'écart :

1. Vérifier d'abord la recette : `diff <(jq 'del(.platform,.device,.files)' pc-a/fingerprint.json) <(jq 'del(.platform,.device,.files)' pc-b/fingerprint.json)`, lancé depuis `SIMU/forward/Point034/` (si `jq` manque : `pixi global install jq`).
2. Si la recette est la même, mesurer l'écart. `resultats.txt` donne les valeurs clés en hexadécimal exact : un écart sur les derniers chiffres hexadécimaux est un écart d'arrondi.
3. Noter le résultat tel quel. Un écart d'arrondi entre deux processeurs différents (Mac ARM et Linux x86-64) peut venir des bibliothèques de calcul propres à chaque processeur. La garantie « au bit » se limite alors à une même architecture, et l'écart est publié.

### 4.5 Ce que la preuve couvre

- **Deux Mac M1, `IDENTIQUE`** : deux machines distinctes de même architecture, montées de zéro, donnent le même calcul au bit.
- **Mac M1 et Linux x86-64, `IDENTIQUE`** : la reproduction tient aussi quand on change de processeur et de système.
- Ce que la preuve ne couvre pas : une autre version des bibliothèques (sans `--frozen`), un GPU, ou un autre twin que `twin_direct` de Point034. Pour un twin MCMC, la même commande compare en plus `chain_state.npz` tableau par tableau.

---

## 5. Pannes courantes

| Symptôme | Cause | Remède |
|---|---|---|
| `bootstrap` : l'espace existe déjà | nom déjà pris | `rm -rf "$ESPACE"`, ou un autre `MACHINE` |
| `uv sync` : pas de paquet `jaxlib` | Mac Intel, Alpine, glibc < 2.27 | Changer de machine (voir la partie 0) |
| `uv: command not found` | `uv` lancé hors de `pixi run -e simu` | Reprendre la commande de l'étape 1.6 telle quelle |
| `run` : `E_STRICT_PRERELEASE` | `--strict` ajouté | Lancer `run` sans `--strict` |
| `lab build` : `E_PROCESSED_SCHEMA` | un ancien `processed_data/` traîne | Monter un espace neuf |
| Empreinte du lab différente sur B | commits de `data` ou `Molonaviz` différents | Refaire l'étape 1.6 sur B |
| `recette différente : twin_id` | autre code, autres données ou autres paramètres | Refaire l'étape 1.6, puis monter un espace neuf |
| `recette différente : jaxlib` | `uv sync` sans `--frozen` | Monter un espace neuf, `uv sync --frozen` |
| `git push` refusé | pas d'accès en écriture à SIMU | Étape 1.3, ou variante sans GitHub |
| `git commit` refusé | nom et e-mail git absents | Étape 1.1 |

---

## 6. Nettoyage

```bash
rm -rf "$ESPACE" ~/simu-montage      # un espace ne resservira pas
```

Le dépôt SIMU est public : n'y déposer que des exports.
