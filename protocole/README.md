# Protocole de l'expérience SIMU

Le twin direct de Point034 est calculé sur deux Mac M1, dans deux espaces neufs. Chaque Mac dépose son export dans ce dépôt, sous `forward/Point034/<machine>/`. Le second Mac compare son résultat au bit près à celui du premier.

## Sur chaque Mac, deux commandes

Il faut un Mac Apple Silicon et un compte GitHub invité comme collaborateur de ce dépôt (l'invitation arrive par e-mail ; l'accepter avant de commencer).

```bash
git clone https://github.com/KeanuToofa/SIMU.git
cd SIMU/protocole

# 1. Une seule fois par Mac : git, pixi, gh (connexion GitHub), ComplexGitSync
bash 1_installer_mac.sh               # ajouter --ssh si l'accès GitHub se fait par clé SSH

# 2. À chaque exécution : monter un espace neuf et lancer le calcul (environ 3 minutes)
bash 2_monter_et_lancer.sh m1-a       # premier Mac
bash 2_monter_et_lancer.sh m1-b       # second Mac : compare à m1-a
```

Pour ne rien envoyer dans le dépôt, ajouter `--sans-push` à la commande 2.

Tant que cette branche n'est pas fusionnée, cloner avec `git clone -b protocole-simu https://github.com/KeanuToofa/SIMU.git`.

## Résultat attendu

- Premier Mac : « aucune autre machine : rien à comparer pour l'instant ». Son export est poussé.
- Second Mac : `m1-a : identique`.
- Dans `resultats.txt` : `water_flux_mean = -4.524782784649976e-07` et `rmse_total = 0.11620092968527289`.
- Codes de sortie : 0 identique, 1 différent, 2 refus avant le calcul.

## Contenu

| Fichier | Rôle |
|---|---|
| `1_installer_mac.sh` | Installe et vérifie les outils du Mac, sans toucher à ce qui existe déjà |
| `2_monter_et_lancer.sh` | Télécharge `simu-direct.cgs`, monte l'espace, aligne les commits, lance le calcul, affiche le résultat |
| `3_aligner_commits.sh` | Replace l'espace sur les commits de la première machine (appelé par le script 2) |
| `TUTO_SIMU.md` | Le protocole détaillé, étape par étape, avec le dépannage |

## À savoir

- Deux Mac doivent calculer aux mêmes commits : le script 3 les aligne seul.
- Un espace ne sert qu'à un seul calcul : chaque exécution monte un espace neuf, dans `~/.cgs/simu-<machine>`.
- Ce dépôt est public : n'y déposer rien de privé.
