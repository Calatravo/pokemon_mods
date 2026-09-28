# Installation by platform

[Español](#español) · [English](#english) · [Français](#français)

The current Pokémon Z download guide describes Windows as the recommended platform, Android through JoiPlay as an alternative, macOS through Wine as an unofficial alternative, and provides no iOS installation method. Pokémon Z is an RPG Maker XP/mkxp-z game. The mod does not include or download the game itself.

Sources: [Pokémon Z download and platform guide](https://pokemonzfangame.com/download/), [official JoiPlay downloads](https://joiplay.net/), and [JoiPlay's Android mkxp source, which automatically loads `preload.rb`](https://github.com/joiplay/android-mkxp/blob/master/app/src/play/java/cyou/joiplay/rpgm/MainActivity.java).

## Español

### Windows — recomendado

1. Cierra Pokémon Z y conserva una copia de tus partidas.
2. Descarga `Pokemon-Z-Mods-v1.1.3.zip` de la release y descomprímelo.
3. Haz doble clic en `Install Pokemon Z Mods.cmd`.
4. Selecciona la carpeta que contiene directamente `Game.exe`.
5. Inicia el juego y comprueba que `Mods/HardcoreNuzlocke/nuzlocke.log` contiene `PASS (14 hooks)`.

El instalador no necesita permisos de administrador, no modifica `Data/Scripts.rxdata` y conserva copias de seguridad de `preload.rb` y `mkxp.json`.

### Android — JoiPlay / Kirin

Consulta las [instrucciones Android con capturas](README.md#instalación-en-android). Hay un [instalador APK de prueba](installer/android/README.md) que pide la carpeta del juego y su edición, guarda copias de seguridad y comprueba el registro después del arranque. Descarga la [APK v1.1.3](https://github.com/Calatravo/pokemon_mods/releases/download/v1.1.3/Pokemon-Z-Mods-v1.1.3-Android-Installer.apk) desde la release.

JoiPlay necesita también RPG Maker Plugin y puede pedir importar el RTP de RPG Maker XP desde sus ajustes. Añade el `Game.exe` de la carpeta ya preparada. Los asistentes Random/Nuzlocke aparecen después de la selección inicial, no en el título.

La prueba de JoiPlay usa correcciones de la versión 1.1.3 que no están en los ZIP 1.1.2 publicados. Kirin no se ha validado: falló antes de cargar el juego en el emulador. Consulta el [informe y sus límites](docs/android-validation.md). Como alternativa, prepara la carpeta en PC con el instalador del código actual y cópiala al móvil.

### Steam Deck y Linux — Wine/Proton

1. En Steam Deck cambia al modo Escritorio. En Linux abre una terminal.
2. Descomprime `Pokemon-Z-Mods-v1.1.3.zip`.
3. Ejecuta, sustituyendo la ruta y el perfil cuando corresponda:

```bash
chmod +x install.sh
./install.sh "/ruta/a/Pokemon Z V2.18" --profile es_218
```

Perfiles: `es_218`, `en_213` y `fr_212p1`. Después añade `Game.exe` como juego que no es de Steam y fuerza Proton, o ejecútalo con Wine. El instalador solo necesita Python 3, incluido de serie en SteamOS.

### macOS — Wine, CrossOver o Whisky

La web de Pokémon Z menciona Wine como alternativa no oficial. Instala primero el juego dentro de una carpeta accesible por Wine/CrossOver/Whisky y ejecuta el mismo `install.sh` de Linux. Si Python 3 no está instalado, usa el método manual de `INSTALL.md`. La compatibilidad puede depender del wrapper y de la versión de macOS.

### iOS y otras plataformas

No se publica un paquete iOS porque la web del juego no ofrece un método compatible. ChromeOS, consolas y otros sistemas no están validados; Android mediante JoiPlay puede funcionar en algunos Chromebooks, pero no se considera una plataforma probada del mod.

## English

### Windows — recommended

Extract `Pokemon-Z-Mods-v1.1.3.zip`, double-click `Install Pokemon Z Mods.cmd`, and select the folder that directly contains `Game.exe`. The installer does not require administrator privileges, never edits `Data/Scripts.rxdata`, and backs up `preload.rb` and `mkxp.json`.

### Android — JoiPlay / Kirin

See the [Android instructions](README.en.md#android-installation) and the [test APK installer](installer/android/README.md). It selects the game folder and edition, backs up changed files and checks the log after startup. Download the [v1.1.3 APK](https://github.com/Calatravo/pokemon_mods/releases/download/v1.1.3/Pokemon-Z-Mods-v1.1.3-Android-Installer.apk) from the release.

JoiPlay also needs RPG Maker Plugin and may require importing the RPG Maker XP RTP through its settings. Add `Game.exe` from the prepared folder. Random/Nuzlocke setup appears after the initial selection, not at the title screen.

The successful JoiPlay test uses version 1.1.3 fixes missing from the published 1.1.2 ZIPs. Kirin is unconfirmed: it failed before starting the game in the emulator. See the [report and limitations](docs/android-validation.md). Alternatively, prepare the folder on a PC using the current-source installer, then copy it to Android.

### Steam Deck/Linux and macOS

Use `install.sh` as shown above, selecting `es_218`, `en_213`, or `fr_212p1`. Steam Deck/Linux runs the game through Proton or Wine. macOS can use Wine, CrossOver, or Whisky, but the game's website classifies Mac/Wine as an unofficial alternative.

### iOS

No iOS package is provided because the Pokémon Z guide does not provide a compatible iOS installation method.

## Français

### Windows — recommandé

Décompressez `Pokemon-Z-Mods-v1.1.3.zip`, double-cliquez sur `Install Pokemon Z Mods.cmd`, puis sélectionnez le dossier contenant directement `Game.exe`. L'installateur ne demande pas de droits administrateur, ne modifie jamais `Data/Scripts.rxdata` et sauvegarde `preload.rb` et `mkxp.json`.

### Android — JoiPlay / Kirin

Consultez les [instructions Android](README.fr.md#installation-sur-android) et l’[installateur APK de test](installer/android/README.md). Il demande le dossier et l’édition du jeu, sauvegarde les fichiers modifiés et vérifie le journal après le démarrage. Téléchargez l’[APK v1.1.3](https://github.com/Calatravo/pokemon_mods/releases/download/v1.1.3/Pokemon-Z-Mods-v1.1.3-Android-Installer.apk) depuis la release.

JoiPlay nécessite également RPG Maker Plugin et peut demander l’importation du RTP de RPG Maker XP depuis ses paramètres. Ajoutez le `Game.exe` du dossier préparé. Les assistants Random/Nuzlocke apparaissent après le choix initial, pas sur l’écran titre.

Le test réussi sous JoiPlay utilise des corrections de la version 1.1.3 absentes des ZIP 1.1.2 publiés. Kirin reste non validé : le moteur a échoué avant le démarrage du jeu sur l’émulateur. Voir le [rapport et ses limites](docs/android-validation.md). Vous pouvez aussi préparer le dossier sur PC avec l’installateur du code actuel, puis le copier sur Android.

### Steam Deck/Linux et macOS

Utilisez `install.sh` comme indiqué plus haut, avec le profil `es_218`, `en_213` ou `fr_212p1`. Steam Deck/Linux utilise Proton ou Wine. macOS peut utiliser Wine, CrossOver ou Whisky, mais le site du jeu considère Mac/Wine comme une solution alternative non officielle.

### iOS

Aucun paquet iOS n'est publié, car le guide de Pokémon Z ne fournit aucune méthode d'installation compatible avec iOS.
