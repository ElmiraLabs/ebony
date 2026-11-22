# `ebony token` : créer, lister et révoquer les jetons d'accès

```
ebony token create <nom> [--expire AAAA-MM-JJ] [--json]   crée un jeton et l'affiche une seule fois
ebony token list [--json]                                 liste les jetons (jamais leur secret)
ebony token revoke <identifiant> [--json]                 révoque un jeton
```

À lancer dans le dossier d'un projet Ebony (un `ebony.conf`). La base est celle de la configuration du projet, comme pour [`ebony migrate`](migrate.md) (`ebony env` la montre). La commande fonctionne avec SQLite et PostgreSQL ; HFSQL est refusé.

> Cette commande **gère** les jetons ; ce sont les **routes générées** par `ebony make resource` qui les **vérifient** : sans `Authorization: Bearer eb_…` valide, elles répondent 401, et un jeton révoqué est refusé à la requête suivante.

## Comment ça marche

- **Le jeton** est un secret aléatoire de 32 octets en Base64 URL, précédé de `eb_` : 46 caractères, par exemple `eb_3q2-7wAAAAA…`. Le préfixe aide les outils qui cherchent des secrets oubliés.
- **Le secret n'est affiché qu'une fois, à la création.** La base ne garde que son **empreinte** (SHA-256) : même quelqu'un qui lit la base ne peut pas s'en servir, et Ebony ne peut pas le retrouver. Un secret perdu se remplace : révoquez le jeton, créez-en un autre.
- **La table** s'appelle `eb_jetons`. Elle est créée par la migration que le module `auth` fournit (`database/migrations/M202611100000_CreeEbJetons.owl`, écrite par `ebony new` et `ebony init`), que vous appliquez avec `ebony migrate`. `token create` refuse, et dit de lancer `ebony migrate`, si elle manque.
- **L'identifiant** montré par `list` est le début de l'empreinte (12 caractères). Il désigne un jeton pour `revoke` et ne permet pas de retrouver le secret.
- **Le nom** est une étiquette libre (60 caractères au plus). Plusieurs mots après `create` forment un seul nom (`ebony token create robot de nuit`). Deux jetons peuvent porter le même nom.
- **`--expire AAAA-MM-JJ`** : le jeton vaut jusqu'à la **fin de ce jour, en UTC**, puis il est refusé. Une date passée ou qui n'existe pas est refusée. Sans `--expire`, le jeton n'expire pas.
- **`revoke`** refuse le jeton aussitôt. Révoquer deux fois, ou un identifiant inconnu, donne le code 1 : un script doit voir l'échec.
- **L'état** d'un jeton dans `list` : `actif`, `expiré` ou `révoqué` (révoqué l'emporte sur expiré).

## Codes de sortie

| Code | Cas |
|---|---|
| 0 | réussite |
| 1 | échec : base injoignable, table ou enregistrement refusés, aucun jeton actif à cet identifiant, configuration invalide |
| 2 | usage incorrect : sous-commande absente ou inconnue, nom ou identifiant manquant ou incorrect, option inconnue, `--expire` hors de `create` ou date incorrecte ou passée |

## Sortie `--json`

Une seule ligne, rien d'autre sur la sortie.

```
create : {"ok":true,"command":"token create","id":"46bdfff49098","name":"ci","token":"eb_…","expiresAt":"","notes":[…]}
list   : {"ok":true,"command":"token list","tokens":[{"id":"…","name":"ci","createdAt":"…","expiresAt":"","revokedAt":"","status":"active"}]}
revoke : {"ok":true,"command":"token revoke","id":"46bdfff49098","revoked":true}
```

`token` n'est donné que par `create`, une seule fois. En cas d'échec : `{"ok":false,"error":"…"}`. `status` vaut `active`, `expired` ou `revoked`.

## Pièges courants

- **Ce sont des jetons d'accès pour des clients, pas une connexion d'utilisateur.** Il n'y a pas encore de connexion par mot de passe.
- **Le secret ne se relit pas.** Copiez-le à la création.
- **Deux `token create` lancés en même temps** ne sont pas protégés l'un de l'autre.
- **Une table `eb_jetons` absente** : lancez `ebony migrate`. `list` et `revoke` ne la créent pas non plus.
