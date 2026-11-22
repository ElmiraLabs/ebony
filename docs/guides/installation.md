# Installer Ebony

**Prérequis** : [OWL](https://github.com/followthewhiteowl/neowl) dans le `PATH`, dans la version indiquée par la [compatibilité](/guides/compatibilite), et `git`. Ebony tourne sous Windows et sous Linux.

Pour l'instant, Ebony s'installe depuis ses sources. L'installation en une seule commande suivra la première release publiée.

## Windows

```powershell
git clone https://github.com/ElmiraLabs/ebony C:\sources\ebony
C:\sources\ebony\bin\ebony.cmd install
```

Ouvrez ensuite un **nouveau terminal** (le `PATH` n'est lu qu'au démarrage d'un terminal) et vérifiez :

```powershell
ebony doctor
```

`ebony install` copie Ebony dans `%LOCALAPPDATA%\Programs\ebony\<version>\` et ajoute son dossier `bin` au `PATH` **de l'utilisateur** : aucun droit d'administrateur n'est nécessaire. La copie installée est autonome : le clone peut être supprimé.

**Mettre à jour** : `git pull` dans le clone, puis `ebony install`. Une nouvelle version s'installe à côté de l'ancienne ; relancer la commande sans changement de version ne fait rien.

**Retirer Ebony** : `ebony uninstall` retire Ebony du `PATH` et supprime les versions installées par `ebony install`. C'est la seule commande d'Ebony qui supprime des fichiers, et elle est bornée : elle ne touche que les dossiers qu'`ebony install` a posés. Vos projets ne sont jamais touchés. Fermez les terminaux ouverts dans le dossier d'Ebony avant de la lancer.

### Pièges courants

- **N'ouvrez pas un terminal en administrateur.** `ebony install` n'en a pas besoin, et un clone fait en administrateur est ensuite refusé par git depuis un terminal normal (« dubious ownership »).
- **Une commande `ebony` introuvable juste après l'installation** : ouvrez un nouveau terminal.
- **Un nom d'utilisateur avec un accent** (`C:\Users\Hélène`) : si `owl` refuse un fichier passé par un chemin absolu accentué, mettez OWL à jour vers la version indiquée par la [compatibilité](/guides/compatibilite). `ebony install` vous le dit si la copie échoue.

## Linux

```sh
git clone https://github.com/ElmiraLabs/ebony ~/ebony
chmod +x ~/ebony/bin/ebony
ln -s ~/ebony/bin/ebony ~/.local/bin/ebony
```

Vérifiez que `~/.local/bin` est dans votre `PATH`, puis :

```sh
ebony --version
ebony doctor
```

Les commandes `ebony install` et `ebony uninstall` n'existent pas sous Linux : elles modifient le `PATH` par le registre de Windows et répondent par un refus (code 2). Pour retirer Ebony, supprimez le lien et le dossier cloné.

Le parcours des [premiers pas](premiers-pas.md) fonctionne sous Linux avec le lanceur `bin/ebony`. La distribution testée est Ubuntu 26.04 (WSL 2) : voir [Ebony sous Linux](linux.md).

## Dans un projet cloné avec git

Le dossier `ebony/` (la bibliothèque d'exécution) n'est pas versionné, comme `node_modules`. Après un `git clone` de votre projet, lancez :

```
ebony restore
```

`restore` recopie `ebony/` d'après la version minimale notée dans `ebony.conf`. Pour aligner ensuite le projet sur l'Ebony installé, lancez `ebony upgrade`. Aucune des deux commandes ne supprime ni ne rétrograde rien : pour mettre à niveau un projet dont `ebony/` existe déjà, supprimez ce dossier, puis lancez `ebony upgrade`.

`upgrade` ne met à jour que `ebony/` et `ebony.conf`. Le code généré dans votre projet (services, contrôleurs, repositories, tests, migrations) reste tel quel.

Si une version plus récente demande une variable de configuration (par exemple `APP_ENV`), `upgrade` ne l'ajoute pas à `config/env.json`, qui est à vous : il vous la **signale** à chaque lancement tant qu'elle manque. Ajoutez-la à la main : sa définition (clé, type, défaut) est dans le manifeste du module, `ebony/modules/<module>.json`, membre `environnement`. Ensuite, `ebony env` la liste.
