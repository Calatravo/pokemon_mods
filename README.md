# Pokémon Z Mods

Mod de desafíos configurables para **Pokémon Z V2.18**. Añade Nuzlocke forzado, Random y Randomlocke desde la primera partida, asistentes de configuración, ayudas de aprendizaje en combate y una tabla de tipos integrada.

> Este repositorio no incluye Pokémon Z, ROMs, ejecutables, gráficos, música, partidas guardadas ni otros recursos del juego. Necesitas una copia obtenida legalmente de Pokémon Z V2.18.

## Instalación rápida

1. Cierra el juego y haz una copia de seguridad de su carpeta y de tus partidas.
2. Descarga este repositorio con **Code > Download ZIP** y descomprímelo.
3. Abre PowerShell en la carpeta descomprimida.
4. Ejecuta, cambiando la ruta por la de tu instalación:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\Juegos\Pokemon Z V2.18"
```

El instalador copia el mod a `Mods\HardcoreNuzlocke`, guarda una copia de seguridad de `preload.rb` y añade únicamente el cargador necesario. **No modifica `Data\Scripts.rxdata`.** Puedes volver a ejecutar el mismo comando para actualizar el mod.

Consulta [INSTALL.md](INSTALL.md) para la instalación manual, verificación, actualización, solución de problemas y desinstalación.

## Funciones principales

- Nuzlocke configurable con reglas obligatorias, cláusula de duplicados, shiny, topes de nivel, objetos en combate, estilo Fijo, regalos, huevos y zonas.
- Random configurable con progresión por medallas, especies, movimientos, evoluciones, tipos, habilidades, objetos, MT y generaciones permitidas.
- Flujo inicial que permite escoger Nuzlocke, Random, Randomlocke o partida normal desde la primera partida.
- Menú de desafíos dentro de Opciones y del menú de pausa.
- Ayudas de combate configurables: eficacia, multiplicadores, tipos del rival, comparación al cambiar de Pokémon y aviso de ataques sin efecto.
- Ficha del movimiento al pulsar `X` sobre un ataque durante el combate.
- Tabla de tipos con iconos y nombres, vista defensiva/ofensiva y desplazamiento para relaciones extensas.
- Cementerio, seguimiento de encuentros y detección de derrota total para Nuzlocke.

La descripción técnica completa y los controles están en [la documentación del módulo](mod/HardcoreNuzlocke/README.md).

## Pantallazos

| Desafíos configurables | Configuración Random |
| --- | --- |
| ![Centro de desafíos](docs/screenshots/01-desafios.jpg) | ![Configuración del modo Random](docs/screenshots/02-configuracion-random.jpg) |

| Tabla de tipos | Ayudas de combate |
| --- | --- |
| ![Tabla de tipos integrada](docs/screenshots/03-tabla-tipos.jpg) | ![Configuración de ayudas de combate](docs/screenshots/04-ayudas-combate.jpg) |

| Información de un movimiento |
| --- |
| ![Ficha de movimiento durante el combate](docs/screenshots/05-ficha-ataque.jpg) |

## Compatibilidad

- Pokémon Z **V2.18** para Windows.
- El instalador está pensado para la distribución que contiene `Game.exe`, `preload.rb` y `Data\Scripts.rxdata` en la carpeta principal.
- Otros mods que reemplacen los mismos métodos pueden causar incompatibilidades. Conserva siempre la copia de seguridad.

## Estado y diagnóstico

Al iniciar el juego se crea `Mods\HardcoreNuzlocke\nuzlocke.log`. Una carga correcta termina con:

```text
PASS (12 hooks)
```

Si el juego se cierra o una pantalla no abre, adjunta ese registro al crear una incidencia.

## Aviso legal

Proyecto de aficionados, gratuito y no oficial. Pokémon y sus marcas pertenecen a sus respectivos propietarios. Este proyecto no está afiliado, respaldado ni patrocinado por Nintendo, Game Freak, Creatures Inc. ni The Pokémon Company.
