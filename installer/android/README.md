# Instalador Android de Pokémon Z Mods

APK de prueba para instalar el mismo mod en una carpeta de juego usada por JoiPlay o Kirin. Descarga la [APK v1.1.3 de la release](https://github.com/Calatravo/pokemon_mods/releases/download/v1.1.3/Pokemon-Z-Mods-v1.1.3-Android-Installer.apk). La aplicación sigue siendo experimental. Instalar los archivos para Kirin no confirma que su motor pueda ejecutar el juego; consulta las [pruebas reales](../../docs/android-validation.md).

## Uso

1. Instala `Pokemon-Z-Mods-v1.1.3-Android-Installer.apk` y abre **Pokémon Z Mods**. Android puede pedir autorización para instalar desde la aplicación con la que abras la APK.
2. Cierra el juego. Pulsa **Elegir carpeta del juego** y selecciona la carpeta descomprimida que contiene `Game.exe`; concede acceso a esa carpeta.
3. Confirma la **edición del juego**, no el idioma que prefieras para el mod. Si el SHA-256 de `Data/Scripts.rxdata` coincide con una edición conocida, se selecciona automáticamente. Si no, el instalador exige elegirla. Rechaza una edición que contradiga una identificación conocida.
4. Pulsa **Instalar / actualizar mod**. Guarda y verifica copias de los archivos existentes antes de escribir. No modifica partidas ni `Data/Scripts.rxdata`.
5. Añade `Game.exe` a JoiPlay o Kirin. En JoiPlay instala también RPG Maker Plugin y, si lo solicita, importa el RTP de RPG Maker XP desde los ajustes de JoiPlay.
6. Abre el juego, ciérralo y vuelve a **Comprobar instalación**. La aplicación distingue los archivos correctos de la carga confirmada por `PASS (14 hooks)` y `Compatibility profile PASS`.

La aplicación está traducida al español, inglés y francés según el idioma de Android. No necesita Internet, root, permisos para todos los archivos ni una cuenta. Usa el selector de carpetas de Android (Storage Access Framework). Requiere Android 8 o posterior. Coloca el juego en una subcarpeta accesible, por ejemplo `Documents/PokemonZ`, no en `Android/data`.

Las copias se guardan dentro del juego en `PokemonZMods-backups/fecha-hora/`, con un archivo `RESTORE.txt`: copia las entradas `RESTORE` a sus rutas originales y elimina únicamente los archivos enumerados como `NEW` si necesitas deshacer esa instalación. Los errores de escritura provocan una restauración automática; ante un cierre forzado, pérdida de energía o fallo de restauración, utiliza esa copia. No borres toda la carpeta Mods, que puede contener otros mods.

El registro anterior del mod también se guarda y se vacía durante la instalación para que un PASS antiguo no cuente como prueba nueva. La comprobación valida los archivos de esta APK; si instalas posteriormente otra versión, usa su instalador correspondiente.

## Compilar y probar en Windows

Necesitas un JDK con `javac`, Android SDK Platform 35 y Build Tools 35.0.0. No necesita Gradle ni descargar dependencias al compilar.

```powershell
powershell -ExecutionPolicy Bypass -File installer/android/test.ps1
powershell -ExecutionPolicy Bypass -File installer/android/build.ps1
```

Salida: `dist/android-installer/Pokemon-Z-Mods-Android-Installer-test.apk`. Se genera una clave local de prueba en `%LOCALAPPDATA%/PokemonZMods/android-installer-test.keystore`, fuera del repositorio. No publiques esa clave ni uses esta firma como identidad de una release estable. Mantén la misma clave entre compilaciones locales para permitir actualizar la APK.

Puedes pasar `-Sdk`, `-JavaHome` y `-OutputPath` para otras rutas. Para publicar, usa `-Release -Keystore <ruta> -KeyAlias <alias>`, con las contraseñas en `PZ_APK_STORE_PASSWORD` y `PZ_APK_KEY_PASSWORD`. El modo `-Release` deriva `versionCode`, `versionName` y el nombre de la APK del archivo `VERSION`, y exige una clave del proyecto. Guarda esa clave y sus credenciales fuera del repositorio: son necesarias para las próximas actualizaciones de la aplicación. Si instalaste la APK local de prueba con otra firma, desinstala solo esa aplicación antes de instalar la pública; conserva la carpeta del juego.

El empaquetado incluye solamente los archivos del mod enumerados por Git y el cargador actual. No incluye el juego, JoiPlay, Kirin ni RTP. La APK y los ZIP 1.1.3 incluyen las correcciones de arranque de JoiPlay. Los ZIP 1.1.2 anteriores no las contienen.

Referencia de almacenamiento: [selección de directorios con Android SAF](https://developer.android.com/training/data-storage/shared/documents-files).
