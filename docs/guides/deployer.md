# Déployer une application

Ebony n'a pas de commande de déploiement : une application est un projet OWL ordinaire. Vous la lancez avec `owl serve`, ou vous la compilez en un binaire autonome avec `owl-build`.

Ce guide suit le cas d'une application Ebony sous Linux avec systemd et SQLite. Il indique aussi ce qui n'est pas couvert.

> Testé sous Ubuntu 26.04 (WSL 2), avec SQLite. Versions prises en charge : voir la [compatibilité](/guides/compatibilite).

## Deux façons de lancer l'application

| Voie | Ce qu'il faut sur le serveur | Quand la choisir |
|---|---|---|
| **Un binaire autonome** (`owl-build`) | le binaire et ses fichiers de configuration, rien d'autre | un serveur sans OWL ni Ebony |
| **Les sources** avec `owl serve` | OWL (voir la [compatibilité](/guides/compatibilite)) et le dossier du projet (avec son `ebony/`) | un serveur où vous voulez relancer `ebony migrate` sur place |

Le binaire est le plus simple à poser. Les sources permettent de migrer la base directement sur le serveur.

## Produire le binaire

Depuis une machine qui a `owl-build` et le projet complet :

```sh
owl-build . -o boutique                         # la plateforme de la machine
owl-build . -o boutique --target linux-x86_64   # un binaire Linux, depuis Windows aussi
```

Le résultat est dans `exe/<cible>/`. Un binaire pèse environ 100 Mo ; le premier build est plus long, car OWL extrait alors sa chaîne de compilation. `owl-build --prepare` fait cette extraction à l'avance, sur une machine de construction.

Le dossier `ebony/` (la bibliothèque) n'est pas versionné : sur une machine qui vient de cloner le projet, lancez `ebony restore` **avant** `owl-build` (voir l'[installation](installation.md)).

**Le binaire n'embarque pas la configuration.** Les fichiers décrits ci-dessous doivent se trouver à côté de lui.

## Le dossier de travail

Le service lit sa configuration et sa base **relativement au dossier de travail** (voir la [configuration](configuration.md)). Pour SQLite, un dossier de production minimal ressemble à ceci :

```text
boutique              le binaire (ou le projet, pour la voie des sources)
.env                  la configuration, sans secret
.env.secrets          les secrets
config/env.json       le schéma de la configuration
storage/app.db        la base
```

Si le service est lancé depuis un autre dossier, il **démarre quand même**, mais `GET /api/health` répond `503` avec `"base":"indisponible"`, et tout jeton est refusé. Réglez donc le dossier de travail de votre superviseur (`WorkingDirectory` pour systemd, « Démarrer dans » pour une tâche Windows), et surveillez `/api/health`.

## Lancer

```sh
./boutique --port 8080 --bind 0.0.0.0
```

- Sans option, le service écoute sur `127.0.0.1:8080`, donc **uniquement en local**. `--bind 0.0.0.0` l'expose sur toutes les interfaces.
- `--port` et `--bind` sont les seules options acceptées.
- **Ne mettez jamais `AUTH_ROUTES=ouvertes` en production** : seule cette valeur ouvre les routes générées ; toute autre les protège.
- Une configuration invalide arrête le démarrage, avec toutes les erreurs listées. Vérifiez-la avant avec `ebony env`.

## Les migrations

Le binaire sert l'application ; il n'applique pas les migrations. Deux façons de faire :

- **Sur le serveur** : lancez `ebony migrate` dans le dossier du projet. Cela demande `owl` et `ebony` sur la machine.
- **Avant le déploiement** : appliquez les migrations sur une copie de la base, puis copiez `storage/app.db` sur le serveur. Le binaire lit cette base telle quelle.

Avec PostgreSQL, `ebony migrate` se lance depuis une machine qui atteint la base. Gardez `DB_TLS` à `verifie` en production (voir la [configuration](configuration.md)).

## Sous systemd

Une unité pour `owl serve` (ici avec les sources, dans `/home/ebony/boutique`) :

```ini
[Unit]
Description=Boutique (Ebony, owl serve)
After=network.target

[Service]
Type=simple
User=ebony
WorkingDirectory=/home/ebony/boutique
ExecStart=/usr/local/bin/owl serve --port 8080 --bind 127.0.0.1
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
```

Enregistrez-la dans `/etc/systemd/system/boutique.service`, puis :

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now boutique
```

`WorkingDirectory` est indispensable : sans lui, le service démarre dans un état dégradé.

**Ce que vous observez** :

- **Démarrage** : `owl serve` compile le projet à chaque lancement. Pour un petit projet, `GET /api/health` répond après une dizaine de secondes. Ne réglez pas une sonde de supervision plus stricte que cela.
- **Arrêt** : `systemctl stop` envoie SIGTERM ; le service écrit `Application arrêtée` dans le journal et s'arrête proprement, code 0.
- **Plantage** : `Restart=on-failure` relance le service ; la base ne perd pas les lignes déjà écrites.
- **Journal** : `journalctl -u boutique -o cat` affiche les lignes JSON d'Ebony, puis les deux lignes de texte du démarrage et la ligne d'écoute d'OWL.

## Sauvegarder la base SQLite

Un `cp` de `app.db` pendant que le service écrit peut copier un fichier incohérent. Deux façons sûres.

**À chaud**, avec l'API de sauvegarde de SQLite, par le module `sqlite3` de Python (présent sur Ubuntu) :

```sh
python3 - <<'PY'
import sqlite3
src = sqlite3.connect('/home/ebony/boutique/storage/app.db')
dst = sqlite3.connect('/home/ebony/sauvegarde.db')
src.backup(dst)
dst.close(); src.close()
PY
```

Vérifiez la copie avec `PRAGMA integrity_check` : la réponse doit être `ok`.

**À froid** : arrêtez le service (`systemctl stop boutique`), copiez `storage/app.db`, relancez.

**Restaurer** : arrêtez le service, remplacez `storage/app.db` par la sauvegarde en gardant le propriétaire (`chown ebony:ebony`), puis relancez.

Hors de ce guide : les sauvegardes planifiées (`cron`, minuteur systemd), le chiffrement, l'envoi hors de la machine, et la sauvegarde de `.env.secrets`. Ce dernier contient les secrets : gardez-le hors de la base.

## Surveiller

- **Santé** : `GET /api/health` est public. Il répond `200` si l'application et la base répondent, `503` sinon.
- **Journal** : une ligne JSON par événement sur la sortie standard (voir le [journal](journalisation.md)). Au démarrage, deux lignes de texte ordinaire précèdent les lignes JSON : votre collecteur doit les tolérer. Les refus d'authentification s'écrivent sur la sortie d'erreur, une ligne par requête refusée.
- **Une requête à la fois** : le service traite les requêtes les unes après les autres (voir [Performance](performance-et-limites.md)). Tenez-en compte avant de promettre un débit.

## Pièges courants

- **Un autre superviseur que systemd** (service Windows, conteneur) : aucun fichier d'exemple n'est fourni.
- **HTTPS** : ce guide ne couvre ni le proxy inverse ni le TLS d'OWL. Mettez un proxy devant le service si vous exposez l'API sur Internet.
- **Plusieurs instances** qui partagent une même base SQLite : à éviter.
- **Un chemin de projet avec des accents ou des espaces** : évitez-le sur un serveur.
- **PostgreSQL derrière un binaire** : PostgreSQL est vérifié avec `owl serve`, pas avec le binaire `owl-build`.
- **Les autres distributions Linux** que Ubuntu, et Windows Server, n'ont pas été essayées.
