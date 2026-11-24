# Ebony sous Linux

Le parcours de création d'un projet (`new`, `make`, `migrate`, `token`, `owl serve`, `curl`) fonctionne sous Linux avec le lanceur `bin/ebony`.

> Testé sous Ubuntu 26.04 (WSL 2). Versions prises en charge : voir la [compatibilité](/guides/compatibilite).

## Installer

1. **OWL** : l'archive Linux de la [release d'OWL](https://github.com/followthewhiteowl/neowl/releases), avec `owl` dans le `PATH`.
2. **Ebony**, depuis ses sources :

   ```sh
   git clone https://github.com/ElmiraLabs/ebony ~/ebony
   chmod +x ~/ebony/bin/ebony
   ln -s ~/ebony/bin/ebony ~/.local/bin/ebony
   ```

3. **Le `PATH`** : si `~/.local/bin` n'y est pas, ajoutez-le à `~/.profile`, puis ouvrez un nouveau terminal.

Vérifiez ensuite avec `ebony --version`, puis `ebony doctor` dans un dossier de travail. Le [guide d'installation](installation.md) donne la même procédure pour Windows.

## Ce qui diffère de Windows

- **Pas de `ebony install` ni de `ebony uninstall`** : ils modifient le `PATH` par le registre de Windows. Sous Linux, ils refusent sans rien faire (code 2). Pour retirer Ebony, supprimez le lien et le dossier cloné.
- **Les chemins** : Ebony garde le style `/` d'un chemin Linux dans ses messages. Deux chemins qui ne diffèrent que par la casse sont deux dossiers.
- **Le lanceur** `bin/ebony` accepte les mêmes options que `bin/ebony.cmd` et rend le même code de sortie.

## Pièges courants

- **Un nom de dossier avec des accents ou des espaces** pour un projet : évitez-le, ce cas n'est pas testé.
- **Les autres distributions Linux** que Ubuntu n'ont pas été essayées.
- **PostgreSQL sous Linux** : testé avec le niveau TLS réglable, pas avec une autorité publique.
