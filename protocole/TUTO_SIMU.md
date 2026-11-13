# Expérience SIMU : tuto complet, à faire sur chaque Mac M1

But : le twin direct de Point034 est calculé sur deux Mac M1, dans deux espaces de travail neufs. Chaque Mac dépose son export dans le dépôt `KeanuToofa/SIMU`. Le second Mac compare son résultat au bit près à celui du premier.

Ce tuto a été déroulé en entier sur le Mac de développement (montage d'un espace neuf, puis `simu-direct`, sans push). Durées mesurées : montage 72 s, script 52 s.

## Voie rapide (scripts de ce dossier)

Les étapes 1 et 2 ci-dessous sont automatisées. Depuis le dossier `protocole/` de ce dépôt :

```bash
bash 1_installer_mac.sh          # une fois par Mac (ajouter --ssh pour l'accès par clé SSH)
bash 2_monter_et_lancer.sh m1-a  # à chaque exécution ; m1-b sur le second Mac
```

Le script 2 monte l'espace, aligne les commits sur ceux de la machine déjà présente (script 3), lance le calcul et affiche le résultat. Ce qui suit détaille chaque étape à la main, utile pour comprendre ou dépanner.

## 0. Ce qu'il faut avant de commencer

| Besoin | Détail |
|---|---|
| Machine | Mac à puce Apple Silicon (M1 ou plus récent). Un Mac Intel est refusé par le script (jaxlib 0.11.2 n'a pas de paquet pour lui). |
| Réseau | Accès à GitHub. Tous les dépôts sont publics. |
| Droit d'écriture | Le push vers `KeanuToofa/SIMU` demande d'être connecté à GitHub en tant que `KeanuToofa` ou en tant que collaborateur de ce dépôt. |
| Ordre | Un Mac après l'autre. Le premier exporte, le second compare. |

Noms à choisir une fois pour toutes :

- `m1-a` pour le premier Mac, `m1-b` pour le second. Lettres, chiffres, `.`, `_` et `-` seulement.

## 1. Installation, une seule fois par Mac

### 1.1 Outils de base (git)

```bash
git --version        # si absent, macOS propose d'installer les outils en ligne de commande : accepter
git config --global user.name  "Votre Nom"
git config --global user.email "vous@exemple.fr"
```

Le script fait un commit dans SIMU. Sans nom ni email configurés, il échoue à la fin.

### 1.2 pixi (version 0.81)

```bash
curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION=0.81.0 bash
# Ouvrir un nouveau terminal, puis :
pixi --version       # attendu : pixi 0.81.0
```

`uv` n'est pas à installer à la main : l'environnement `simu` de pixi le fournit.

### 1.3 Accès GitHub pour pousser dans SIMU

Choisir une des deux voies.

**Voie HTTPS avec GitHub CLI (la plus simple sur un Mac neuf) :**

```bash
brew install gh      # ou : pixi global install gh
gh auth login        # GitHub.com, HTTPS, se connecter dans le navigateur avec le compte KeanuToofa
gh auth setup-git
```

**Voie SSH :** avoir une clé SSH déclarée sur le compte GitHub, puis vérifier :

```bash
ssh -T git@github.com    # attendu : « Hi KeanuToofa! You've successfully authenticated… »
```

Retenir la voie choisie : elle décide de l'option `--force-protocol` à l'étape 2.2.


### 1.4 ComplexGitSync (l'outil `cgitsync`)

Le script cherche l'outil dans `$HOME/tools/ComplexGitSync`. Il faut donc l'installer exactement là.

```bash
mkdir -p ~/tools
git clone https://github.com/flipoyo/ComplexGitSync.git ~/tools/ComplexGitSync
cd ~/tools/ComplexGitSync
git checkout 9594d7e     # version 8.6.2 utilisée pour les essais
pixi install
pixi run cgitsync --version    # attendu : cgitsync 8.6.2
```

Si ce dossier existe déjà, ne rien refaire : vérifier seulement la version.

## 2. Protocole à chaque exécution, sur chaque Mac

Un espace ne sert qu'à un seul calcul. Chaque exécution commence donc par un montage neuf.

### 2.1 Récupérer le fichier de montage

```bash
mkdir -p ~/simu-montage && cd ~/simu-montage
curl -fsSL -o simu-direct.cgs \
  https://raw.githubusercontent.com/flipoyo/MOLONARI1D/CGS-MOLO/simu-direct.cgs
cat simu-direct.cgs     # doit lister 5 dépôts : MOLONARI1D, MOLONARI-API, MOLONARI-data, MOLONARI-TWIN, SIMU
```

### 2.2 Monter l'espace (environ 70 s)

**Avec HTTPS** (voie `gh`) :

```bash
cd ~/tools/ComplexGitSync
pixi run cgitsync bootstrap --cgs-path "$HOME/.cgs" --force-protocol https \
  ~/simu-montage/simu-direct.cgs simu-m1-a
```

**Avec SSH** : même commande, sans `--force-protocol https`.

Remplacer `simu-m1-a` par `simu-m1-b` sur le second Mac. À la fin, l'outil affiche `READY ready=true complete=true`. L'espace se trouve alors dans `~/.cgs/simu-m1-a`.

### 2.3 Vérifier l'espace avant de calculer

```bash
cd ~/.cgs/simu-m1-a
git status --short           # attendu : rien
ls                           # doit contenir Molonaviz, MOLONARI-TWIN, SIMU, data, scripts, pixi.toml
for d in . Molonaviz data MOLONARI-TWIN SIMU; do echo "$d $(git -C $d rev-parse --short HEAD)"; done
```

Sur le second Mac, `Molonaviz`, `data` et `MOLONARI-TWIN` doivent avoir les mêmes commits que le premier. Voir l'étape 4 en cas d'écart.

### 2.4 Lancer l'expérience (environ 1 minute)

**Premier Mac :**

```bash
cd ~/.cgs/simu-m1-a
MACHINE=m1-a pixi run -e simu simu-direct
```

**Second Mac :**

```bash
cd ~/.cgs/simu-m1-b
MACHINE=m1-b pixi run -e simu simu-direct
```

Pour un essai sans rien pousser, ajouter `SIMU_PUSH=0` devant la commande.

### 2.5 Lire le résultat

À la fin, le script affiche le compte rendu et la durée de chaque étape.

- **Premier Mac :** `aucune autre machine : rien à comparer pour l'instant.` C'est normal. Son export est poussé dans SIMU.
- **Second Mac :** `m1-a : identique` est le résultat attendu. `m1-a : DIFFÉRENT` signifie que la reproduction n'est pas identique au bit.

Code de sortie : `echo $?` juste après la commande.

| Code | Sens |
|---|---|
| 0 | identique, ou aucune autre machine |
| 1 | au moins une machine DIFFÉRENTE |
| 2 | le script a refusé de partir (rien n'a été calculé) |

Les valeurs du twin direct attendues sont, dans `resultats.txt` :

```text
water_flux_mean = -4.524782784649976e-07
rmse_total      = 0.11620092968527289
```

Le détail est dans `SIMU/forward/Point034/<MACHINE>/` : `resultats.txt`, `commits.json`, `environment.txt`, `compte_rendu.txt` et `compare_<autre>.json`.

## 3. Ce que fait le script, dans l'ordre

1. Contrôles : Mac M1, nom `MACHINE` valide, export absent, cinq dépôts propres.
2. `git pull --ff-only` dans SIMU.
3. `uv sync --frozen` du backend (versions figées par le fichier de verrou).
4. Même commit que les machines déjà présentes dans `SIMU/forward/Point034/`, sinon refus.
5. `lab build`, puis `run` du twin direct (environ 15 s).
6. `reproduce --export` vers `SIMU/forward/Point034/<MACHINE>/`.
7. `reproduce --compare` contre chaque autre machine.
8. Commit et push dans SIMU.

## 4. Pannes courantes

| Message ou symptôme | Cause | Remède |
|---|---|---|
| `REFUS : cette expérience se joue sur un Mac M1` | Mac Intel, Linux ou Windows | Utiliser un Mac Apple Silicon |
| `REFUS : dépôts non propres` | un fichier a été modifié ou ajouté dans un des cinq dépôts | Supprimer le fichier, ou remonter un espace neuf |
| `REFUS : export déjà présent` | `MACHINE` déjà utilisé, ou espace déjà servi | Monter un nouvel espace et choisir un autre `MACHINE` |
| `REFUS : l'espace n'est pas neuf` | un calcul a déjà eu lieu dans cet espace | Monter un nouvel espace |
| `REFUS : commits différents : la machine m1-a a Molonaviz à <sha>…` | `CGS-MOLO` a avancé entre les deux montages | Voir ci-dessous |
| `REFUS : le dépôt SIMU est absent` | espace non monté par `bootstrap` | Refaire l'étape 2.2 |
| Échec de `git push` | pas d'accès en écriture à SIMU | Refaire l'étape 1.3, ou voir « Sans push » |
| Échec de `git commit` | nom et email git absents | Refaire l'étape 1.1 |

**Commits différents.** Sur le second Mac, replacer chaque dépôt cité sur le commit du premier, puis relancer :

```bash
cd ~/.cgs/simu-m1-b
cat SIMU/forward/Point034/m1-a/commits.json      # relever le commit de chaque dépôt
git -C Molonaviz checkout <sha>                  # idem pour data, MOLONARI-TWIN, et . pour la racine
```

Un dépôt en tête détachée est considéré comme propre par le script.

**Sans push (SIMU non joignable).** Lancer avec `SIMU_PUSH=0`. Copier ensuite le dossier `SIMU/forward/Point034/m1-a/` du premier Mac dans le même chemin du second, avant de lancer le second calcul.

## 5. Après l'expérience

- Les deux comptes rendus (`compte_rendu.txt`) montrent le résultat. Un résultat `identique` prouve : deux machines, même architecture, même calcul au bit.
- La preuve ne couvre pas Mac ARM contre Linux x86-64. Ce point reste ouvert.
- Pour supprimer un espace devenu inutile : `rm -rf ~/.cgs/simu-m1-a`.
- Le dépôt SIMU est public : ne rien y déposer qui ne doive pas l'être.
