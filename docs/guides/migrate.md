# `ebony migrate` : appliquer, lister et défaire les migrations

```
ebony migrate [--dry-run] [--json]                      applique les migrations en attente, dans l'ordre
ebony migrate status [--json]                           liste les migrations et leur état
ebony migrate rollback [--pas N] [--dry-run] [--json]   défait la dernière migration appliquée (ou les N dernières)
```

À lancer dans le dossier d'un projet Ebony (un `ebony.conf`), après `ebony make migration`. La base est celle de la configuration du projet (`ebony env` la montre) : `DB_FICHIER` pour SQLite ; `DB_HOTE`, `DB_PORT`, `DB_NOM`, `DB_UTILISATEUR` et `DB_MOT_DE_PASSE` pour PostgreSQL (et `DB_TLS`, `DB_CERTIFICAT_CA` : voir la [configuration](configuration.md)). SQLite et PostgreSQL sont pris en charge ; HFSQL est refusé.

## Comment ça marche

- **Les fichiers.** Les migrations sont les fichiers `database/migrations/M<horodatage>_<Intention>.owl` écrits par `ebony make migration`. Les autres fichiers du dossier sont ignorés. Elles sont appliquées dans l'ordre de leurs noms.
- **Ebony lit le SQL dans le fichier.** Il n'exécute pas la classe : il reconnaît la forme que `make migration` écrit.

  ```
  PROCEDURE PUBLIQUE Monte() : tableau de chaînes
      tabSql est un tableau de chaînes
      TableauAjoute(tabSql, `texte SQL, sur une ou plusieurs lignes`)
      RENVOYER tabSql
  FIN
  ```

  Même chose pour `Descend()`. Une instruction par `TableauAjoute`, dans l'ordre d'envoi. Une migration qui calcule son SQL (concaténation, condition, appel) est refusée, avec le fichier et la ligne : Ebony ne l'applique jamais à moitié. Pour ajouter une colonne à la main, écrivez une migration de cette forme.
- **Chaque instruction est envoyée seule.** Deux instructions séparées par `;` dans un même envoi ne marcheraient pas : seule la première s'exécuterait.
- **Une migration = une transaction.** Si une instruction est refusée, tout est annulé, les migrations précédentes restent appliquées et la commande s'arrête (code 1, avec la migration, le numéro de l'instruction et la cause donnée par la base).
- **Le suivi** est la table `eb_migrations`, créée au premier `migrate` qui a quelque chose à appliquer.
- **Tout est lu avant la première instruction.** Une migration illisible, ou le fichier manquant d'une migration à défaire, arrête la commande sans toucher à la base.

## Les commandes

| Commande | Ce qu'elle fait |
|---|---|
| `migrate` | applique, dans l'ordre, chaque migration absente de `eb_migrations`. Rien en attente : code 0, « Rien à appliquer ». |
| `migrate --dry-run` | dit lesquelles seraient appliquées, sans envoyer d'instruction. |
| `migrate status` | liste toutes les migrations : `applied`, `pending`, ou `missing` (appliquée, mais son fichier n'est plus dans le projet). |
| `migrate rollback` | exécute le `Descend()` de la dernière migration appliquée et retire son inscription. `--pas N` : les N dernières, de la plus récente à la plus ancienne. Si le fichier de l'une d'elles manque, rien n'est défait. |

## Sortie `--json`

Une seule ligne sur la sortie standard :

```json
{"ok":true,"command":"migrate","base":"sqlite","dir":"C:\\Projets\\boutique","dryRun":false,
 "done":["M202611021015_CreeClients"],
 "migrations":[{"name":"M202611021015_CreeClients","status":"applied","appliedAt":"2026-11-07T09:30:00Z"}],
 "notes":[]}
```

| Clé | Sens |
|---|---|
| `command` | `migrate`, `migrate status` ou `migrate rollback` |
| `base` | le fournisseur de `ebony.conf` |
| `dir` | le dossier du projet |
| `dryRun` | `true` pour `--dry-run` |
| `done` | les migrations appliquées ou défaites par la commande (avec `--dry-run` : celles qui le seraient ; vide pour `status`) |
| `migrations` | toutes, dans l'ordre, telles qu'elles sont après la commande ; `appliedAt` est vide si elle n'est pas appliquée |
| `notes` | ce que l'utilisateur doit regarder |

En cas d'échec : `{"ok":false,"error":"…"}`. Sans `--json`, la même chose en texte.

## Codes de sortie

| Code | Cas |
|---|---|
| 0 | réussi (y compris « rien à faire ») |
| 2 | usage incorrect : sous-commande ou option inconnue, `--pas` invalide ou sans `rollback`, `--dry-run` avec `status` |
| 1 | échec : OWL mal placé, pas un projet Ebony, `ebony.conf` sans base, HFSQL, migration non reconnue, base injoignable, instruction refusée par la base (migration annulée), rollback impossible, configuration invalide |

## Pièges courants

- **`status` et `--dry-run` ouvrent la base.** Avec SQLite, si le fichier n'existe pas (`storage/app.db`), il est créé vide, avec son dossier `storage/`. Aucune table n'est créée.
- **Deux migrations écrites dans la même minute** passent dans l'ordre alphabétique de leur intention : vérifiez que l'ordre convient (une clé étrangère doit viser une table déjà créée).
- **Une migration appliquée dont vous modifiez le fichier** après coup n'est pas détectée.
- **Deux `ebony migrate` en même temps** sur la même base ne sont pas protégés l'un de l'autre.
- **PostgreSQL local sans TLS** : OWL refuse le serveur tant que vous n'avez pas écrit `DB_TLS=desactive` dans `.env` (le message d'erreur le dit). En production, gardez `verifie`.
