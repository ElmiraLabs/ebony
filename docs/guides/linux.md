# Ebony sous Linux

Le parcours du guide [premiers pas](premiers-pas.md) (`new`, `make`, `migrate`, `token`, `owl serve`, `curl`) fonctionne sous Linux avec le lanceur `bin/ebony`.

> Référence : Ubuntu 26.04 (WSL 2), Ebony 0.1.5, OWL 1.9.0, SQLite.

## Installer

1. **OWL** : l'archive Linux de la [release d'OWL](https://github.com/followthewhiteowl/neowl/releases), avec `owl` dans le PATH, et `curl`.
2. **Ebony**, en une commande :

   ```sh
   curl -fsSL https://github.com/ElmiraLabs/ebony/releases/latest/download/install.sh | sh
   ```

   L'installateur vérifie la somme SHA-256 de l'archive, la copie dans `~/.local/share/ebony/<version>/` et pose le lien `~/.local/bin/ebony`. Le [guide d'installation](installation.md#en-une-commande) détaille les étapes.
3. **Le PATH** : si `~/.local/bin` n'y est pas, ajoutez-le à `~/.profile`, puis ouvrez un nouveau terminal.

Vérifiez ensuite avec `ebony --version`, puis `ebony doctor` dans un dossier de travail.

Sans l'installateur, un lien suffit : `ln -s /chemin/vers/ebony/bin/ebony ~/.local/bin/ebony` (le lanceur suit les liens pour retrouver son dossier). Si le bit d'exécution manque, `chmod +x bin/ebony`.

## Ce qui diffère de Windows

- **Pas de `ebony install` ni de `ebony uninstall`** : ils modifient le PATH par le registre de Windows. Sous Linux, ces commandes refusent sans rien faire (code 2). Pour retirer Ebony, utilisez `install.sh --uninstall` (voir le [guide d'installation](installation.md#en-une-commande)).
- **Une commande peut être plus lente depuis un clone** : les mini-projets par commande (`.commandes/`) ne sont présents que dans l'archive de distribution. Sans eux, chaque commande recompile Ebony entier.
- **Les chemins** : Ebony garde le style `/` d'un chemin Linux (`/root/essai`) dans tous ses messages. Deux chemins qui ne diffèrent que par la casse sont deux dossiers.
- **Le lanceur** `bin/ebony` accepte les mêmes options que `bin/ebony.cmd` et rend le même code de sortie.

## Ce qui n'est pas couvert

- Les autres distributions Linux et les autres versions d'OWL.
- PostgreSQL sous Linux, avec le niveau TLS `verifie` et une autorité publique.
- `owl test` d'un projet généré sous Linux, au-delà du parcours de base.
- Un chemin de projet contenant des accents ou des espaces.
