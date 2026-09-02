# Pokémon Z Mods

[Español](README.md) · [English](README.en.md) · [Français](README.fr.md)

Mod de défis configurables pour les éditions espagnole, anglaise et française de **Pokémon Z**. Il ajoute les modes Nuzlocke forcé, Random et Randomlocke dès la première partie, des assistants de configuration, des aides d'apprentissage en combat et une table des types intégrée.

> Ce dépôt ne contient ni Pokémon Z, ni ROM, ni exécutable, ni graphismes, ni musique, ni sauvegarde. Une copie obtenue légalement d'une édition compatible est nécessaire.

## Éditions compatibles

| Édition testée | Profil | Langue initiale du mod |
| --- | --- | --- |
| Pokémon Z **2.18 espagnole** | `es_218` | Español |
| Pokémon Z **2.13 anglaise** | `en_213` | English |
| Pokémon Z **2.12 française + Patch 1** | `fr_212p1` | Français |

Les noms de Pokémon, capacités et descriptions proviennent des données localisées de chaque jeu. Tous les menus, explications et messages ajoutés par le mod sont traduits. La langue du mod peut être changée dans les Options sans modifier celle du jeu de base.

## Installation rapide

1. Fermez le jeu et sauvegardez son dossier ainsi que vos sauvegardes.
2. Téléchargez `Pokemon-Z-Mods-v1.0.0.zip` depuis [la dernière release](https://github.com/Calatravo/pokemon_mods/releases/latest), puis décompressez-le.
3. Sous Windows, double-cliquez sur `Install Pokemon Z Mods.cmd` et sélectionnez le dossier contenant `Game.exe`.

Vous pouvez également utiliser PowerShell en adaptant le chemin :

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\Jeux\Pokémon Z V2.12 - Français" -Language auto
```

`auto` détecte l'édition à partir de ses fichiers, même si le dossier a été renommé, puis choisit la langue et le profil. Il est aussi possible d'utiliser `-Language es`, `-Language en` ou `-Language fr`. L'installateur sauvegarde `preload.rb` et `mkxp.json`, active le chargeur, corrige l'ancien wrapper Zlib défectueux des versions 2.12/2.13 et ne modifie jamais `Data\Scripts.rxdata`. La même commande peut être relancée pour mettre le mod à jour.

Consultez [PLATFORMS.md](PLATFORMS.md) pour Android/JoiPlay, Steam Deck, Linux, macOS et l'état d'iOS, ou [INSTALL.md](INSTALL.md) pour l'installation manuelle, la mise à jour, la désinstallation et le dépannage.

## Configuration dès la première partie

Nuzlocke et Random sont disponibles immédiatement, sans terminer le jeu. Après la question Nuzlocke initiale, répondre **Oui** ouvre son assistant. Le jeu demande ensuite toujours si le mode Random doit être activé et, si la réponse est Oui, ouvre son assistant.

Quatre modes de départ sont possibles :

- Partie normale : Nuzlocke et Random désactivés.
- Nuzlocke : seules les règles Locke forcées sont actives.
- Random : seul le randomiseur est actif.
- Randomlocke : Nuzlocke et Random fonctionnent ensemble.

Les réglages habituels sont présélectionnés. Choisir un réglage affiche son explication complète, son effet sur la partie et une confirmation Oui/Non avant tout changement. `Appliquer et continuer` enregistre la configuration. Les réglages Nuzlocke et Random sont verrouillés pour cette sauvegarde après le début de la partie ; les aides d'apprentissage restent modifiables.

## Nuzlocke forcé

### Règles obligatoires

| Règle | Effet |
| --- | --- |
| **Mort permanente** | Un Pokémon à 0 PV est marqué comme mort, ne peut plus être réanimé ni replacé dans l'équipe et rejoint automatiquement la boîte `CIMETIERE`. |
| **Première rencontre** | Seule la première rencontre valide de chaque zone peut être capturée. La mettre K.O. ou fuir consomme l'occasion. Les clauses doublon et chromatique sont évaluées auparavant. |
| **Une capture par zone** | Chaque zone logique possède une capture normale. Les cartes regroupées partagent leur état, sauf si les réglages de méthode ou de sous-zone les séparent. |

### Règles configurables

| Réglage | Défaut | Effet |
| --- | --- | --- |
| **Clause doublon (lignée évolutive)** | Activée | Une rencontre appartenant à une lignée déjà obtenue est ignorée et ne consomme pas la zone. Sa capture est bloquée afin de chercher une autre rencontre. |
| **Clause d'espèce exacte** | Activée | Une espèce déjà obtenue est un doublon, même sans vérifier toute sa lignée évolutive. |
| **Clause chromatique** | Activée | Un Pokémon chromatique peut être capturé dans une zone déjà utilisée. Il est enregistré comme capture supplémentaire. |
| **Limites de niveau** | Activées | L'expérience est limitée par la progression : niveaux 17, 27, 36, 42, 50, 56, 70, 75, 80, 85, 94 et 100. |
| **Aucun objet en combat** | Activé | Les soins, améliorations et objets similaires du Sac sont bloqués. Les Poké Balls restent disponibles pour les captures légales et les objets tenus restent équipés. |
| **Style Défini** | Activé | Force le style Défini et supprime le changement gratuit après le K.O. d'un adversaire. |
| **Les cadeaux consomment la zone** | Désactivé | Les Pokémon offerts et Œufs utilisent la zone de réception. Une zone déjà utilisée bloque le cadeau. Désactivé, ils sont exemptés. |
| **Les statiques consomment la zone** | Activé | Les Pokémon visibles, statiques ou lancés par événement comptent comme rencontre de la zone. |
| **Herbe/eau/pêche partagent la zone** | Activé | Sol, grotte, Surf et pêche partagent une occasion. Désactivé, chaque méthode possède la sienne. |
| **Chaque sous-carte compte séparément** | Désactivé | Chaque carte ou étage interne devient une zone. Désactivé, les parties d'un même lieu sont regroupées. |

Une Poké Ball interdite est rendue et le motif est expliqué. Les rencontres doubles, chromatiques, cadeaux et doublons respectent leurs clauses. `Progression Nuzlocke` affiche zone actuelle, captures, rencontres manquées, chromatiques supplémentaires, morts et limite de niveau. `Registre des zones` conserve l'état de chaque lieu. Si aucun Pokémon apte ne reste, la run est marquée comme terminée sans rendre la sauvegarde inutilisable.

## Mode Random

Les tables aléatoires sont générées puis enregistrées : espèces, talents, évolutions et autres résultats restent cohérents pendant toute la partie.

### Mode des talents

| Mode | Défaut | Effet |
| --- | --- | --- |
| **Full Random** | Sélectionné | Chaque espèce reçoit de nouveaux talents aléatoires. |
| **Correspondance cohérente** | Non sélectionné | Chaque talent d'origine correspond toujours au même remplacement aléatoire dans cette sauvegarde. |
| **Ne pas randomiser** | Non sélectionné | Conserve les talents normaux. |

### Réglages Random configurables

| Réglage | Défaut | Effet |
| --- | --- | --- |
| **Random progressif** | Activé | Limite la puissance de base des espèces et des capacités selon les badges obtenus. |
| **Capacités random** | Activé | Attribue une liste de capacités aléatoire ; le mode progressif adapte aussi leur puissance. |
| **Évolutions random** | Désactivé | Remplace les évolutions par des espèces aléatoires stables pour la sauvegarde. |
| **Évolutions au BST similaire** | Activé | Si les évolutions sont randomisées, préfère une somme de statistiques de base comparable. |
| **Compatibilité CT random** | Activée | Randomise les CT que chaque Pokémon peut apprendre. |
| **Types random** | Désactivés | Attribue des types aléatoires stables, modifiant STAB, faiblesses, résistances et immunités. |
| **Objets au sol random** | Activés | Randomise les objets visibles et cachés à ramassage unique tout en protégeant les objets clés, les CS et les Méga-Gemmes. Les arbres, rochers, caisses de matériaux et plants de Baies renouvelables conservent leurs ressources normales afin d'éviter une récolte aléatoire illimitée. |
| **Cadeaux d'événements aléatoires** | Désactivés | Randomise les cadeaux et récompenses non essentiels remis directement par les événements. Les objets clés, les CS et les Méga-Gemmes restent protégés. |
| **Objets tenus random** | Activés | Permet aux Pokémon sauvages de porter des objets aléatoires sûrs. |
| **Récompenses de Dresseurs random** | Désactivées | Certains Dresseurs vaincus peuvent donner une récompense aléatoire supplémentaire. |
| **Mode Semi Random** | Désactivé | Limite l'aléatoire aux rencontres et cadeaux ; Dresseurs, capacités, talents et objets restent normaux. |

Après l'ajout réussi d'un objet au sol, d'un cadeau d'événement ou d'une récompense dans le Sac, le jeu conserve ses messages habituels puis ouvre une fenêtre séparée avec la description localisée de l'objet. Elle n'apparaît qu'une fois, même pour plusieurs exemplaires, et décrit l'objet réellement reçu après remplacement lorsque le mode Random est actif.

Les générations **1 à 9** sont activées par défaut et peuvent être autorisées séparément. Le randomiseur n'utilise que les générations cochées et empêche de désactiver la dernière.

## Aides d'apprentissage en combat

Ces aides fonctionnent en partie normale, Nuzlocke, Random et Randomlocke. Elles restent modifiables depuis les Options et chaque changement affiche une explication et une confirmation.

| Aide | Défaut | Effet |
| --- | --- | --- |
| **Détails de capacité avec X** | Activés | `X` sur une capacité affiche icône et nom du type, catégorie physique/spéciale/statut, puissance, précision, PP, priorité, efficacité et description localisée. |
| **Efficacité des capacités** | Activée | Affiche `SUPER EFFICACE`, `PEU EFFICACE`, `NORMAL` ou `SANS EFFET`. Une capacité de statut affiche `STATUT`. |
| **Multiplicateurs exacts** | Désactivés | Affiche le multiplicateur combiné (`x0`, `x0.25`, `x0.5`, `x1`, `x2`, `x4`, etc.). |
| **Aide au changement** | Activée | En parcourant l'équipe, compare les rapports offensif et défensif du candidat avec l'adversaire actif. |
| **Avertir si sans effet** | Activé | Demande confirmation avant une capacité offensive de multiplicateur `x0`, sans interrompre les capacités de statut. |
| **Afficher les types adverses** | Activé | Affiche les types de l'adversaire actif au-dessus du sélecteur de capacités. |

## Table des types et menus

La table utilise les icônes du jeu et les noms de types traduits. Gauche/Droite change le type, `C` alterne Défense et Attaque, Haut/Bas fait défiler une liste longue et `X` ou Échap revient. Les relations `x2`, `x1/2` et `x0` restent dans une disposition sûre, y compris pour la longue liste offensive de Roche.

Pendant un combat, appuyez sur `R` dans le sélecteur de capacités pour ouvrir immédiatement la table. La fermer revient à la même capacité sélectionnée sans consommer le tour ni modifier le choix. Le sélecteur affiche `R : Types` à côté du raccourci `X : Infos`.

Entrées ajoutées :

- **Options → Défis** : configuration et état Nuzlocke/Random, progression, zones et Cimetière.
- **Options → Aides d'apprentissage en combat** : les six aides.
- **Options → Table des types** : référence offensive et défensive.
- **Options → Langue du mod** : Español, English ou Français.
- **Menu de pause → Défis** : ouvre le même centre.

## Captures d'écran

| Menu français | Table des types |
| --- | --- |
| ![Menu des défis en français](docs/screenshots/06-defis-fr.png) | ![Table des types](docs/screenshots/03-tabla-tipos.jpg) |

## Diagnostic

Le jeu crée `Mods\HardcoreNuzlocke\nuzlocke.log`. Un démarrage correct contient :

```text
Installation self-test PASS (14 hooks)
Compatibility profile PASS: fr_212p1; language=fr
```

En cas de fermeture ou d'écran inaccessible, joignez ce journal, l'édition exacte du jeu et la liste des autres mods à votre signalement.

## Mentions légales

Projet de fans gratuit et non officiel. Pokémon et ses marques appartiennent à leurs propriétaires. Ce projet n'est ni affilié ni approuvé par Nintendo, Game Freak, Creatures Inc. ou The Pokémon Company.
