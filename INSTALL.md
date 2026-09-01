# Instalación de Pokémon Z Mods

## Antes de empezar

Necesitas Pokémon Z V2.18 para Windows ya instalado. La carpeta correcta contiene, como mínimo:

```text
Pokemon Z V2.18\
├── Game.exe
├── preload.rb
└── Data\Scripts.rxdata
```

Cierra el juego y copia a un lugar seguro tanto su carpeta como tus partidas guardadas. El repositorio no distribuye ni descarga archivos del juego.

## Instalación automática recomendada

1. Descarga el ZIP del repositorio y descomprímelo.
2. Abre PowerShell dentro de la carpeta descomprimida.
3. Ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\ruta\a\Pokemon Z V2.18"
```

El script comprueba que sea una instalación compatible, copia `mod\HardcoreNuzlocke` a la carpeta `Mods` del juego y añade un bloque delimitado al final de `preload.rb`. La primera ejecución también crea:

```text
preload.rb.backup-before-pokemon-mods
```

El instalador es repetible: vuelve a ejecutar el mismo comando para actualizar los archivos del mod sin duplicar el cargador.

## Instalación manual

1. Copia la carpeta `mod\HardcoreNuzlocke` completa dentro de `Mods` en la carpeta del juego. El resultado debe ser:

```text
Pokemon Z V2.18\Mods\HardcoreNuzlocke\loader.rb
```

2. Haz una copia de seguridad de `preload.rb`.
3. Abre `preload.rb` con un editor de texto.
4. Copia al final todo el contenido de [installer/preload-snippet.rb](installer/preload-snippet.rb).
5. Guarda el archivo en UTF-8 y arranca el juego.

No copies ni reemplaces `Data\Scripts.rxdata`: el cargador instala el puente necesario en memoria durante el arranque.

## Verificación

Después de abrir el juego, comprueba el archivo:

```text
Pokemon Z V2.18\Mods\HardcoreNuzlocke\nuzlocke.log
```

La validación correcta termina con `PASS (12 hooks)`. Después podrás encontrar en Opciones:

- `Desafíos - Abrir`
- `Ayudas de combate - Configurar`
- `Tabla de tipos - Abrir`

En una partida nueva, Nuzlocke y Random estarán disponibles sin haber completado antes el juego.

## Actualización

Cierra el juego, descarga la versión nueva y vuelve a ejecutar `install.ps1` con la misma ruta. El instalador conserva la copia de seguridad inicial de `preload.rb` y sustituye los archivos del mod.

Haz una copia adicional del guardado antes de actualizar una partida con un desafío ya iniciado.

## Desinstalación

Con el juego cerrado:

1. Elimina de `preload.rb` el bloque comprendido entre `BEGIN POKEMON_MODS HARDCORE_NUZLOCKE` y `END POKEMON_MODS HARDCORE_NUZLOCKE`. Si no has añadido después ningún otro cambio a `preload.rb`, también puedes restaurar la copia `preload.rb.backup-before-pokemon-mods`.
2. Elimina la carpeta `Mods\HardcoreNuzlocke`.

No continúes una partida Nuzlocke/Random importante sin el mod hasta haber conservado antes una copia del guardado.

## Solución de problemas

### PowerShell bloquea el script

Usa exactamente el comando de la guía, que aplica `ExecutionPolicy Bypass` solo a esa ejecución. No cambia la política global del equipo.

### La ruta no es válida

Pasa la carpeta que contiene directamente `Game.exe`, no la carpeta `Data`, `Mods` ni una carpeta superior. Mantén las comillas si la ruta contiene espacios.

### El juego se cierra al arrancar

Restaura temporalmente `preload.rb.backup-before-pokemon-mods`, conserva `nuzlocke.log` y abre una incidencia incluyendo el registro, la versión exacta del juego y cualquier otro mod instalado.

### No aparecen los menús

Comprueba que exista `Mods\HardcoreNuzlocke\loader.rb` y revisa que `nuzlocke.log` termine en `PASS (12 hooks)`. Si no es así, vuelve a ejecutar el instalador y revisa el primer error del registro.
