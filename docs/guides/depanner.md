# Dépanner

Voici les pannes les plus fréquentes, avec les messages tels qu'ils s'affichent. Pour un diagnostic général, lancez `ebony doctor` dans le dossier du projet : cinq contrôles (accès au dossier, installation, écriture, version d'OWL, état du projet), un bilan, et pour chaque problème ce qu'il faut faire.

## Les commandes

### `'owl' n'est pas reconnu en tant que commande interne ou externe`

`owl` n'est pas dans le `PATH` du terminal. Installez OWL, ou ouvrez un **nouveau** terminal si vous venez de le faire : un `PATH` modifié n'est lu qu'au démarrage d'un terminal. Contrôle : `owl --version`. La version attendue est dans la [compatibilité](/guides/compatibilite) ; une autre version donne un avertissement de `ebony doctor`.

### `Ce dossier n'est pas un projet ebony : ebony.conf est introuvable`

Vous n'êtes pas à la racine d'un projet. `ebony migrate`, `make`, `token` et `env` se lancent dans le dossier qui contient `ebony.conf` : ils ne remontent pas vers les dossiers parents. Pour créer un projet : `ebony new <nom>`.

### `'cEbServiceApplication' : variable inconnue ou inaccessible`

Le dossier `ebony/` (la bibliothèque) manque. C'est normal après un `git clone`, car `ebony/` n'est pas versionné. Lancez `ebony restore`, puis `owl --check projet.owl` passe.

### Une erreur de syntaxe dans l'un de vos fichiers

`owl --check projet.owl` répond en JSON, avec le fichier et la ligne :

```json
{"errors":[{"file":"app/services/Casse.owl","line":1,"message":"app/services/Casse.owl:3 : Expression attendue."}]}
```

Le numéro de la ligne en cause est dans le texte du message.

### `ebony make migration` : `il faut au moins un champ en plus de la clé « id »`

Une migration décrit une table : donnez la clé et au moins une autre colonne (`id:entier*,nom:texte`).

## La configuration

### `ebony env` signale une variable en erreur

`ebony env` lit `config/env.json`, `.env` et `.env.secrets` comme l'application, et dit d'où vient la valeur de chaque variable. Exemple avec `AUTH_ROUTES=Ouvertes` :

```text
  ERREUR AUTH_ROUTES (liste) : .env

Erreurs (1) :
  - AUTH_ROUTES : l'une de ces valeurs : protegees, ouvertes attendu, reçu « Ouvertes » (lu dans .env).
```

Une valeur de liste s'écrit exactement comme dans le schéma, en minuscules. Au démarrage, la même erreur arrête le service : voir [la configuration](configuration.md).

### `/api/health` répond 503 `{"statut":"degrade","base":"indisponible"}`

L'application n'a pas trouvé sa base. Cause la plus fréquente : le service a été lancé depuis un autre dossier que celui du projet, donc sans `.env` ni `config/env.json`. Le service démarre quand même (le journal dit `Base injoignable au démarrage`), et tout jeton est refusé. Lancez-le depuis la racine du projet ; avec un superviseur, réglez son dossier de travail. Voir [déployer](deployer.md).

### `ebony migrate` applique de nouveau des migrations déjà jouées

Vous êtes sur une autre base. Une faute dans `DB_FICHIER` ne provoque aucune erreur : avec `DB_FICHIER=nexiste/pas/app.db`, `ebony migrate` crée les dossiers `nexiste/pas/` et une base neuve et vide, puis applique toutes les migrations dessus. Un service lancé ainsi tourne sur une base vide. Vérifiez la valeur avec `ebony env`, cherchez un `app.db` inattendu dans le projet, et supprimez-le à la main une fois la bonne valeur remise.

## Les jetons et les routes

### `no such table: eb_jetons`

La table des jetons n'existe pas encore : lancez `ebony migrate`. Sa migration, `M…_CreeEbJetons`, est dans `database/migrations/`. L'ordre des [premiers pas](premiers-pas.md) est `migrate`, puis `token create`.

### Une route générée répond 401

La réponse est toujours la même, sans dire pourquoi : `401 non_autorise`. Vérifiez dans l'ordre :

1. L'en-tête est exactement `Authorization: Bearer eb_…` (le secret entier, 46 caractères).
2. Le jeton existe et n'est ni révoqué ni expiré : `ebony token list`, colonne « état ».
3. La base répond : `GET /api/health` doit donner 200. Sans base, tout jeton est refusé.

Le secret ne se relit pas : un jeton perdu se remplace (`ebony token revoke`, puis `ebony token create`). Le service écrit une ligne `rejet auth …` sur sa sortie d'erreur pour chaque refus.

### Sous PowerShell, `curl` ne se comporte pas comme prévu

Utilisez `curl.exe` : `curl` est un alias de `Invoke-WebRequest`. Pour lire le corps d'une réponse d'erreur, ajoutez `-i`. PowerShell 5.1 retire les guillemets d'un JSON passé en argument : écrivez le corps dans un fichier et envoyez-le avec `--data-binary @fichier`.

## Le lancement du service

### `ecoute impossible sur 127.0.0.1:18200 (bind (code 10048))`

Le port est déjà pris, souvent par une instance précédente du service. Choisissez un autre port (`owl serve --port 8081`) ou arrêtez le processus qui l'occupe (sous Windows, `Get-NetTCPConnection -LocalPort 18200` donne son identifiant). Le premier service n'est pas touché.

## Les tests

### `owl test` : `Type inconnu 'cM…_CreeX'`

Vous avez supprimé une migration (`database/migrations/M…_CreeX.owl`) mais pas son test : `ebony make migration` écrit les deux. Supprimez aussi `tests/integration/migrations/test_M…_CreeX.owl`.

### `ALL CLEAR (0 suites, 0 assertions)`

Ce n'est pas une réussite : rien n'a été exécuté. Un projet sans ressource générée n'a pas de test d'application. Avec `--filter`, un nom qui ne correspond à aucun nom de fichier (la casse compte) donne aussi 0 suite et le code 0. Vérifiez le nombre de suites, et utilisez `owl test -vv` pour voir quelle assertion échoue.

## PostgreSQL : `serveur refuse TLS, anti-downgrade`

OWL exige par défaut un TLS vérifié vers PostgreSQL et refuse un serveur qui n'en propose pas. Pour un serveur **local de développement** sans TLS, mettez `DB_TLS=desactive` dans `.env`. En production, gardez `verifie`. Les quatre niveaux sont décrits dans la [configuration](configuration.md).

## Les chemins avec des accents

Un projet dans un dossier accentué (`Café\boutique`) fonctionne avec `ebony new`, `ebony migrate`, `owl --check projet.owl` et `owl serve`. Sous Windows, si `owl` refuse un fichier donné par un chemin absolu accentué (« cannot open file »), lancez-le depuis le dossier du projet avec des chemins relatifs, ou mettez OWL à jour (voir la [compatibilité](compatibilite.md)).

## Si rien de cela ne correspond

Lancez la commande avec `--json` quand elle l'accepte (une ligne, `{"ok":false,"error":"…"}`), relevez le code de sortie ([les erreurs](erreurs.md), [les commandes](commandes.md)) et ouvrez un [ticket](https://github.com/ElmiraLabs/ebony/issues) avec la commande, la sortie complète, `ebony --version`, `owl --version` et votre système.
