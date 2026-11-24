# Introduction

> **Ebony est un framework pour OWL qui apporte une structure, des conventions et des outils pour construire des API maintenables, sans enfermer le développeur dans une boîte noire.**

**OWL** est un langage de programmation dont les mots-clés sont en français (`SI`, `ALORS`, `FIN`, `POUR TOUT`). Sa commande `owl` vérifie, exécute et teste un projet, et lance un serveur HTTP avec `owl serve`. Il n'a **aucun rapport** avec l'OWL du W3C (le *Web Ontology Language*). Ebony est un projet indépendant, non affilié à l'équipe d'OWL.

Ebony apporte à OWL ce que les frameworks apportent à leur langage : une façon cohérente de structurer un projet, de décrire ses données, d'exposer une application et de la protéger. Sa structure s'inspire d'[AdonisJS](https://adonisjs.com), un framework Node.js.

Le dépôt `ElmiraLabs/ebony` est le cœur : la commande `ebony`, les générateurs et la petite bibliothèque d'exécution (`Eb*`) que chaque projet généré embarque.

Quelques commandes suffisent pour obtenir une API qui tourne. Pour une table, `ebony make` écrit l'entité, le repository, le service, le contrôleur REST et les tests.

Le code généré est du code OWL ordinaire, dans votre projet : vous le lisez, vous le modifiez, et il reste à vous.

> **Préversion 0.1.5.** Ebony crée aujourd'hui des API REST pour OWL. Il est encore en développement : ses commandes, ses conventions et ses fonctionnalités peuvent évoluer.

## Pour qui

Ebony s'adresse aux développeurs OWL qui veulent une API structurée sans écrire chaque couche à la main, et qui veulent garder la main sur le code produit.

Aujourd'hui, le framework sert à faire des API REST. Les applications web et de bureau ne sont pas encore disponibles.

## Par où commencer

1. [Installation](/guides/installation) : installer Ebony, après OWL.
2. [Référence des commandes](/guides/commandes) : toutes les commandes.
3. [Modules et kits](/guides/modules) : ce que contient un projet.
4. [La feuille de route](https://github.com/ElmiraLabs/ebony/blob/main/ROADMAP.md) : ce qui arrive.

## L'écosystème

Ebony se construit par couches : le cœur d'abord, puis un type de projet à la fois.

| Projet | Description | État |
|---|---|---|
| **Ebony (cœur)** | Commande `ebony`, générateurs, bibliothèque d'exécution, système de modules. | Disponible (préversion) |
| **Kit API** | Routes, contrôleurs, services, repositories, migrations et jetons d'accès. C'est le kit par défaut de `ebony new`. | Disponible (préversion) |
| **Kit slim** | Le cœur seul, sans base de données ni jetons : `ebony new <nom> --kit slim`. | Disponible (préversion) |
| **Web** | Applications avec pages rendues côté serveur. | Pas encore |
| **Bureau** | Applications de bureau. | Pas encore |
| **Mobile** | Applications mobiles. | À l'étude |

Un kit est une liste de modules. Le kit API prend `burin` (la base de données), `poincon` (la validation) et `auth` (les jetons). Le détail est dans [les modules](/guides/modules).

## Principes

**Votre code vous appartient.** Ebony génère du code OWL lisible dans votre projet. `ebony make` ne remplace jamais un fichier existant, et Ebony ne supprime rien sans le dire : seule `ebony uninstall` supprime des fichiers, dans un périmètre borné et annoncé.

**Explicite plutôt que magique.** OWL n'a ni espaces de noms ni paquets : les noms globaux de la bibliothèque commencent donc par `Eb`. Rien n'est deviné : une route est protégée parce que son contrôleur le dit.

**Sûr par défaut.** Les routes générées exigent un jeton. Un secret n'est affiché qu'à sa création, la base n'en garde que l'empreinte, et la configuration n'affiche jamais sa valeur. Ouvrir une route est un choix (`AUTH_ROUTES=ouvertes`), jamais un oubli.

**Des couches séparées.** Le contrôleur parle HTTP et vérifie ce qui arrive. Le service porte les règles métier. Le repository parle à la base. Chaque accès au système passe par un port, avec un adaptateur réel et un adaptateur de test : on peut tester sans base ni disque.

**Un cœur modulaire.** Le cœur ne dépend d'aucun module. Chaque module déclare ce qu'il apporte dans un manifeste.

**Honnête sur ses limites.** OWL ne permet pas tout (hachage lent, fils d'exécution, lancement de programmes externes…). Ces limites sont documentées, au lieu d'être contournées en silence.
