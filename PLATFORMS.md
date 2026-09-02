# Installation by platform

[Español](#español) · [English](#english) · [Français](#français)

The current Pokémon Z download guide describes Windows as the recommended platform, Android through JoiPlay as an alternative, macOS through Wine as an unofficial alternative, and provides no iOS installation method. Pokémon Z is an RPG Maker XP/mkxp-z game. The mod does not include or download the game itself.

Sources: [Pokémon Z download and platform guide](https://pokemonzfangame.com/download/), [official JoiPlay downloads](https://joiplay.net/), and [JoiPlay's Android mkxp source, which automatically loads `preload.rb`](https://github.com/joiplay/android-mkxp/blob/master/app/src/play/java/cyou/joiplay/rpgm/MainActivity.java).

## Español

### Windows — recomendado

1. Cierra Pokémon Z y conserva una copia de tus partidas.
2. Descarga `Pokemon-Z-Mods-v1.0.0.zip` de la release y descomprímelo.
3. Haz doble clic en `Install Pokemon Z Mods.cmd`.
4. Selecciona la carpeta que contiene directamente `Game.exe`.
5. Inicia el juego y comprueba que `Mods/HardcoreNuzlocke/nuzlocke.log` contiene `PASS (14 hooks)`.

El instalador no necesita permisos de administrador, no modifica `Data/Scripts.rxdata` y conserva copias de seguridad de `preload.rb` y `mkxp.json`.

### Android — JoiPlay

1. Instala versiones actuales de [JoiPlay y RPG Maker Plugin](https://joiplay.net/).
2. Descarga y descomprime primero la edición compatible de Pokémon Z.
3. Haz una copia del guardado y del `preload.rb` original.
4. Descarga el ZIP Android correspondiente a tu edición: ES 2.18, EN 2.13 o FR 2.12 + Patch 1.
5. Extrae su contenido dentro de la carpeta de Pokémon Z, la misma que contiene `Game.exe`. Autoriza combinar `Mods` y reemplazar `preload.rb`.
6. En JoiPlay pulsa `+`, añade `Game.exe` y usa el RPG Maker Plugin. Si ya estaba añadido, ciérralo por completo y vuelve a abrirlo.
7. Tras iniciar, revisa `Mods/HardcoreNuzlocke/nuzlocke.log` con el explorador de archivos.

JoiPlay carga automáticamente el `preload.rb` situado junto a `Game.exe`; no es necesario modificar `Scripts.rxdata`. Android sigue siendo una vía alternativa y puede variar según dispositivo, versión de JoiPlay y permisos de almacenamiento.

### Steam Deck y Linux — Wine/Proton

1. En Steam Deck cambia al modo Escritorio. En Linux abre una terminal.
2. Descomprime `Pokemon-Z-Mods-v1.0.0.zip`.
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

Extract `Pokemon-Z-Mods-v1.0.0.zip`, double-click `Install Pokemon Z Mods.cmd`, and select the folder that directly contains `Game.exe`. The installer does not require administrator privileges, never edits `Data/Scripts.rxdata`, and backs up `preload.rb` and `mkxp.json`.

### Android — JoiPlay

Install current versions of [JoiPlay and its RPG Maker Plugin](https://joiplay.net/). Back up your save and original `preload.rb`, download the Android ZIP matching ES 2.18, EN 2.13, or FR 2.12 + Patch 1, and extract it into the folder containing `Game.exe`. Merge `Mods` and replace `preload.rb`. Add `Game.exe` to JoiPlay, close and reopen JoiPlay, then verify that `Mods/HardcoreNuzlocke/nuzlocke.log` reports `PASS (14 hooks)`.

### Steam Deck/Linux and macOS

Use `install.sh` as shown above, selecting `es_218`, `en_213`, or `fr_212p1`. Steam Deck/Linux runs the game through Proton or Wine. macOS can use Wine, CrossOver, or Whisky, but the game's website classifies Mac/Wine as an unofficial alternative.

### iOS

No iOS package is provided because the Pokémon Z guide does not provide a compatible iOS installation method.

## Français

### Windows — recommandé

Décompressez `Pokemon-Z-Mods-v1.0.0.zip`, double-cliquez sur `Install Pokemon Z Mods.cmd`, puis sélectionnez le dossier contenant directement `Game.exe`. L'installateur ne demande pas de droits administrateur, ne modifie jamais `Data/Scripts.rxdata` et sauvegarde `preload.rb` et `mkxp.json`.

### Android — JoiPlay

Installez les versions actuelles de [JoiPlay et de son RPG Maker Plugin](https://joiplay.net/). Sauvegardez votre partie et le `preload.rb` original, téléchargez le ZIP Android correspondant à ES 2.18, EN 2.13 ou FR 2.12 + Patch 1, puis extrayez-le dans le dossier contenant `Game.exe`. Fusionnez `Mods` et remplacez `preload.rb`. Ajoutez `Game.exe` à JoiPlay, redémarrez complètement JoiPlay, puis vérifiez que `Mods/HardcoreNuzlocke/nuzlocke.log` contient `PASS (14 hooks)`.

### Steam Deck/Linux et macOS

Utilisez `install.sh` comme indiqué plus haut, avec le profil `es_218`, `en_213` ou `fr_212p1`. Steam Deck/Linux utilise Proton ou Wine. macOS peut utiliser Wine, CrossOver ou Whisky, mais le site du jeu considère Mac/Wine comme une solution alternative non officielle.

### iOS

Aucun paquet iOS n'est publié, car le guide de Pokémon Z ne fournit aucune méthode d'installation compatible avec iOS.
