# Compatibilité

Cette page indique les versions et les plateformes prises en charge. Les autres guides y renvoient : ils ne répètent pas les numéros.

## Versions

| Élément | Version |
|---|---|
| Ebony | 0.1.5 (préversion) |
| OWL | 1.9.0 (version de référence) |

`ebony doctor` compare la version d'OWL installée à la version de référence, et le signale si elles diffèrent. Une autre version d'OWL peut fonctionner, mais elle n'est pas testée.

## Plateformes

- **Windows** : PowerShell 5.1 ou plus récent, fourni avec le système.
- **Linux** : testé sous Ubuntu 26.04 avec WSL 2.

## Bases de données

| Base | Migrations (`ebony migrate`) | Ressources (`ebony make`) | Connexion |
|---|---|---|---|
| SQLite | oui | oui | oui |
| PostgreSQL 16 | oui | oui | oui (niveau TLS réglable) |
| HFSQL | non | non | oui |

Avec HFSQL, Ebony se connecte à la base, mais ne génère ni migrations ni ressources.

## Kits

- **`api`** (par défaut) : base de données, validation et jetons d'accès.
- **`slim`** : le cœur seul, sans base de données ni jetons.

Le détail est dans [les modules](/guides/modules).

Cette page est mise à jour à chaque version d'Ebony.
