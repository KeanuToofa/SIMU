# SIMU

Expérience de reproductibilité de MOLONARI-TWIN : le twin direct de Point034 est calculé dans plusieurs operating
spaces, et chaque calcul doit donner les mêmes résultats au bit près.

- `forward/Point034/<MACHINE>/` : export d'une machine (`molonari-twin reproduce --export`), avec `commits.json` et
  l'environnement (`cgitsync env show`).
- Chaque machine compare son export à ceux déjà présents (`molonari-twin reproduce --compare`) et dépose son compte
  rendu.

L'operating space se monte depuis MOLONARI1D avec `cgitsync bootstrap simu-direct.cgs`, puis
`pixi run simu-direct`.
