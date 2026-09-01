# Instalación de Pokémon Z Mods

## Antes de empezar

Necesitas una de estas ediciones para Windows ya instalada:

- Pokémon Z V2.18 española.
- Pokémon Z V2.13 inglesa.
- Pokémon Z V2.12 francesa con Patch 1.

La carpeta correcta contiene, como mínimo:

```text
Pokemon Z V2.18\
├── Game.exe
├── preload.rb
├── mkxp.json
└── Data\Scripts.rxdata
```

Cierra el juego y copia a un lugar seguro tanto su carpeta como tus partidas guardadas. El repositorio no distribuye ni descarga archivos del juego.

## Instalación automática recomendada

1. Descarga el ZIP del repositorio y descomprímelo.
2. Abre PowerShell dentro de la carpeta descomprimida.
3. Ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\ruta\a\Pokemon Z V2.18" -Language auto
```

El script detecta la edición por la ruta, elige su perfil, copia `mod\HardcoreNuzlocke` a la carpeta `Mods` del juego, activa `preload.rb` en `mkxp.json` y añade o reutiliza el cargador. Para forzar una edición se puede usar:

```powershell
-Language es
-Language en
-Language fr
```

También admite el parámetro avanzado `-Profile es_218`, `-Profile en_213` o `-Profile fr_212p1`. El idioma y el perfil deben corresponder.

La primera ejecución crea:

```text
preload.rb.backup-before-pokemon-mods
mkxp.json.backup-before-pokemon-mods
```

Las ediciones 2.12/2.13 incluyen en `preload.rb` un antiguo wrapper Zlib que falla al activarlo; el instalador retira únicamente ese bloque conocido y conserva la copia original. El instalador es repetible: vuelve a ejecutar el mismo comando para actualizar los archivos del mod sin duplicar el cargador ni la entrada de `mkxp.json`.

## Instalación manual

La instalación manual solo se recomienda si conoces la edición exacta, porque también debes activar la precarga y configurar el perfil.

1. Copia la carpeta `mod\HardcoreNuzlocke` completa dentro de `Mods` en la carpeta del juego. El resultado debe ser:

```text
Pokemon Z V2.18\Mods\HardcoreNuzlocke\loader.rb
```

2. Haz una copia de seguridad de `preload.rb`.
3. Abre `preload.rb` con un editor de texto.
4. Copia al final todo el contenido de [installer/preload-snippet.rb](installer/preload-snippet.rb).
5. Comprueba que `mkxp.json` contenga una propiedad activa `"preloadScript": ["preload.rb"]`.
6. Edita `Mods\HardcoreNuzlocke\Config\install_profile.rb` con el idioma y perfil correctos.
7. Guarda los archivos en UTF-8 y arranca el juego.

No copies ni reemplaces `Data\Scripts.rxdata`: el cargador espera a que estén disponibles las clases del juego e instala los hooks en memoria durante el arranque.

## Verificación

Después de abrir el juego, comprueba el archivo:

```text
Mods\HardcoreNuzlocke\nuzlocke.log
```

La validación correcta contiene `PASS (13 hooks)` y `Compatibility profile PASS`. Después podrás encontrar en Opciones:

- `Desafíos - Abrir`
- `Ayudas de combate - Configurar`
- `Tabla de tipos - Abrir`
- `Idioma del mod`

En una partida nueva, Nuzlocke y Random estarán disponibles sin haber completado antes el juego.

## Actualización

Cierra el juego, descarga la versión nueva y vuelve a ejecutar `install.ps1` con la misma ruta. El instalador conserva la copia de seguridad inicial de `preload.rb` y sustituye los archivos del mod.

Haz una copia adicional del guardado antes de actualizar una partida con un desafío ya iniciado.

## Desinstalación

Con el juego cerrado:

1. Elimina de `preload.rb` el bloque comprendido entre `BEGIN POKEMON_MODS HARDCORE_NUZLOCKE` y `END POKEMON_MODS HARDCORE_NUZLOCKE`. Si no has añadido después ningún otro cambio, también puedes restaurar `preload.rb.backup-before-pokemon-mods`.
2. Restaura `mkxp.json.backup-before-pokemon-mods` si el instalador tuvo que activar la precarga.
3. Elimina la carpeta `Mods\HardcoreNuzlocke`.

No continúes una partida Nuzlocke/Random importante sin el mod hasta haber conservado antes una copia del guardado.

## Solución de problemas

### PowerShell bloquea el script

Usa exactamente el comando de la guía, que aplica `ExecutionPolicy Bypass` solo a esa ejecución. No cambia la política global del equipo.

### La ruta no es válida

Pasa la carpeta que contiene directamente `Game.exe`, no la carpeta `Data`, `Mods` ni una carpeta superior. Mantén las comillas si la ruta contiene espacios.

### El juego se cierra al arrancar

Restaura temporalmente las copias de `preload.rb` y `mkxp.json`, conserva `nuzlocke.log` y abre una incidencia incluyendo el registro, la versión exacta del juego, el idioma y cualquier otro mod instalado.

### No aparecen los menús

Comprueba que exista `Mods\HardcoreNuzlocke\loader.rb` y revisa que `nuzlocke.log` termine en `PASS (13 hooks)`. Si no es así, vuelve a ejecutar el instalador y revisa el primer error del registro.
