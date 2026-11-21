<div align="center">

<img src="assets/logo-ebony.png" width="200" alt="Logo Ebony : une tête d'éléphant souriant, oreilles orange">

# Ebony

**Le cœur du framework Ebony : des applications OWL structurées, générées par une commande.**

Inspiré d'AdonisJS, pour le langage de programmation [OWL](https://github.com/followthewhiteowl/neowl) (sans rapport avec l'OWL du W3C, le Web Ontology Language).

[![Version 0.1.5](https://img.shields.io/badge/Version-0.1.5-orange?style=for-the-badge)](https://github.com/ElmiraLabs/ebony/releases)
[![Licence MIT](https://img.shields.io/github/license/ElmiraLabs/ebony?style=for-the-badge&label=Licence)](LICENSE)
[![OWL 1.9.0](https://img.shields.io/badge/OWL-1.9.0-blue?style=for-the-badge)](https://github.com/followthewhiteowl/neowl)
[![Plateformes : Windows et Linux](https://img.shields.io/badge/Plateformes-Windows%20%7C%20Linux-lightgrey?style=for-the-badge)](https://elmiralabs.github.io/ebony/guides/installation)

[Installation](#installation) ·
[Démarrage rapide](#démarrage-rapide) ·
[Documentation](https://elmiralabs.github.io/ebony/) ·
[Contribuer](#contribuer)

</div>

---

## Présentation

**Ebony** donne à OWL ce que les frameworks web donnent à leur langage : une façon **cohérente** de démarrer un projet, de décrire ses données, d'exposer une application et de la protéger.

Une commande crée un projet qui compile et démarre sous `owl serve`. Une autre écrit, pour une table, l'entité, les repositories, le service métier, le contrôleur REST et les tests, avec des routes protégées par jeton. Le code généré est lisible et reste le vôtre.

> **Préversion 0.1.5.** Ebony crée en une seule commande une API REST pour OWL. Cette version est une préversion : elle peut encore évoluer.

## Installation

Prérequis : [OWL](https://github.com/followthewhiteowl/neowl) **1.9.0** dans le `PATH` (`owl --version`), sous Windows ou Linux. Une autre version donne un avertissement de `ebony doctor`. Pour l'instant, Ebony s'installe depuis ses sources.

**Windows** (PowerShell) :

```powershell
git clone https://github.com/ElmiraLabs/ebony C:\sources\ebony
C:\sources\ebony\bin\ebony.cmd install
```

Ouvrez ensuite un nouveau terminal et lancez `ebony doctor`.

**Linux** :

```sh
git clone https://github.com/ElmiraLabs/ebony ~/ebony
chmod +x ~/ebony/bin/ebony
ln -s ~/ebony/bin/ebony ~/.local/bin/ebony
```

Vérifiez que `~/.local/bin` est dans votre `PATH`, puis lancez `ebony doctor`.

Le [guide d'installation](https://elmiralabs.github.io/ebony/guides/installation) détaille les deux voies. L'installation en une seule commande suivra la première release publiée.

## Démarrage rapide

Ebony installé (voir [Installation](#installation)), créez une API, migrez-la, protégez-la par un jeton et lancez-la :

```powershell
ebony new boutique ; cd boutique
Copy-Item .env.exemple .env ; Copy-Item .env.secrets.exemple .env.secrets
ebony make migration CreeProduits --champs 'id:entier*,nom:texte,prix:reel,actif:booleen'
ebony make resource Produit --champs 'id:entier*,nom:texte,prix:reel,actif:booleen' --table produits
ebony migrate
ebony token create essai          # le secret (eb_…) n'est affiché qu'une fois : copiez-le
owl serve --port 8080
```

Puis, dans un second terminal (le secret du jeton à la place de `eb_…`) :

```powershell
curl.exe -s -H "Authorization: Bearer eb_…" http://127.0.0.1:8080/api/produits       # []
```

Sans jeton, la même requête répond **401**. Sous Linux : `cp` à la place de `Copy-Item`. Le [parcours détaillé](https://elmiralabs.github.io/ebony/guides/premiers-pas) explique chaque étape.

## Documentation

**Toute la documentation est sur [elmiralabs.github.io/ebony](https://elmiralabs.github.io/ebony/).** Pour commencer :

- [Introduction](https://elmiralabs.github.io/ebony/guides/introduction) : ce qu'est Ebony, ses kits et sa philosophie.
- [Premiers pas](https://elmiralabs.github.io/ebony/guides/premiers-pas) et le [tutoriel d'une petite boutique](https://elmiralabs.github.io/ebony/guides/tutoriel).
- [Structure d'un projet](https://elmiralabs.github.io/ebony/guides/structure) : où est quoi, pour chaque kit.
- [Référence des commandes](https://elmiralabs.github.io/ebony/guides/commandes) et [les modules](https://elmiralabs.github.io/ebony/guides/modules).
- [Adopter Ebony dans un projet existant](https://elmiralabs.github.io/ebony/guides/adopter-un-projet).

## Contribuer

Les contributions sont les bienvenues, même petites : un rapport de bug clair aide autant qu'une correction. Avant de commencer, lisez le [guide de contribution](https://github.com/ElmiraLabs/ebony/blob/main/.github/CONTRIBUTING.md) et le [code de conduite](https://github.com/ElmiraLabs/ebony/blob/main/.github/CODE_OF_CONDUCT.md). Pour signaler une faille de sécurité, suivez la [politique de sécurité](https://github.com/ElmiraLabs/ebony/blob/main/.github/SECURITY.md) : pas de ticket public.

Ebony est un projet indépendant, **non affilié** à l'équipe du langage OWL (NeOwl) : il s'appuie sur la commande `owl` publiée par ce projet, sans la modifier ni l'embarquer.

## Licence

[MIT](LICENSE), au nom d'ElmiraLabs.
