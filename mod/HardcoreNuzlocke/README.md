# Desafíos configurables - Pokémon Z

Este módulo añade Nuzlocke forzado, Random configurable y Randomlocke a las ediciones española 2.18, inglesa 2.13 y francesa 2.12 + Patch 1. Los modos están disponibles desde la primera partida y su estado se guarda dentro de la partida.

## Idiomas y perfiles

El instalador genera `Config/install_profile.rb` con uno de estos pares:

- `LANGUAGE = :es`, `PROFILE = :es_218`.
- `LANGUAGE = :en`, `PROFILE = :en_213`.
- `LANGUAGE = :fr`, `PROFILE = :fr_212p1`.

Todos los menús, explicaciones, preguntas y avisos del mod están traducidos. Pokémon, movimientos y descripciones se leen de los datos localizados del juego; los nombres de los 18 tipos se incluyen en las traducciones del mod porque algunas distribuciones conservan esos nombres internos en español. El jugador puede cambiar el idioma del mod en Opciones y la elección se guarda en `$PokemonSystem`.

## Inicio de una partida

La elección Nuzlocke original está disponible desde la primera partida. Después de responderla, el juego abre el asistente Nuzlocke si se eligió Sí y, a continuación, siempre pregunta si se desea activar Random. Si se responde Sí a Random, abre inmediatamente su configuración. De este modo se puede empezar en Nuzlocke, Random, Randomlocke o partida normal sin completar antes el juego.

Cada modo usa su propio asistente a pantalla completa. Al seleccionar una regla, la explicación, el efecto sobre la partida, la pregunta de activación o desactivación y los botones Sí/No se muestran juntos. La última opción es `Aplicar y continuar`.

Al aplicar un modo, su configuración queda bloqueada para ese guardado. Así no se pueden relajar las reglas a mitad de una partida.

## Acceso posterior

- Menú de opciones: `Desafíos - Abrir`.
- Menú de opciones: `Ayudas de combate - Configurar`.
- Menú de opciones: `Tabla de tipos - Abrir`.
- Menú de opciones: `Idioma del mod` (`Español`, `English` o `Français`).
- Menú de pausa: selecciona la nueva entrada `Desafíos`. También se conserva el atajo `S` (`R` en el sistema de entrada del juego).

Desde el centro de desafíos se puede consultar el estado de los modos, el progreso, las zonas, los encuentros perdidos y el cementerio. Una configuración ya aplicada puede revisarse, pero no alterarse.

La tabla de tipos muestra el icono y el nombre de cada tipo. Izquierda y derecha cambian de tipo; C alterna entre defensa y ataque; arriba y abajo desplazan las relaciones cuando no caben; X o Esc vuelve al menú. La distribución en tres columnas evita que tipos con muchas relaciones, como Roca, salgan de la pantalla. En el selector de movimientos de un combate, `R` abre la tabla y vuelve después al mismo movimiento sin consumir el turno.

## Ayudas para aprender en combate

La pantalla `Ayudas de combate` permite activar o desactivar individualmente:

- Ficha completa del ataque al pulsar X sobre él durante el combate.
- Etiquetas de eficacia en cada ataque.
- Multiplicadores exactos (`x0`, `x0.5`, `x1`, `x2` o `x4`).
- Comparación ofensiva y defensiva al recorrer el equipo durante un cambio.
- Confirmación antes de usar un ataque de daño sin efecto.
- Nombre de los tipos del rival en el selector de ataques.

La ficha de ataque usa el icono del juego y el nombre localizado del tipo y muestra categoría, potencia, precisión, PP, prioridad, eficacia contra el rival y descripción. Los movimientos de estado se identifican como tales y no reciben una etiqueta de eficacia de daño engañosa. Las ayudas habituales vienen activadas y se guardan por partida.

## Nuzlocke

Reglas obligatorias:

- Debilitamiento permanente.
- Solo cuenta el primer encuentro válido.
- Una captura por zona.

Opciones configurables, con las reglas habituales preactivadas:

- Cláusulas de duplicados por línea evolutiva y por especie exacta.
- Excepción para Pokémon shiny.
- Topes de nivel ligados al progreso.
- Prohibición de objetos en combate.
- Estilo de combate Fijo.
- Tratamiento de regalos, huevos y encuentros estáticos.
- Zona compartida entre hierba, agua y pesca.
- División opcional por submapas.

El primer encuentro queda consumido aunque se debilite o se huya. Las capturas no válidas se bloquean y la Poké Ball se devuelve. Los Pokémon debilitados no pueden revivir y se trasladan al último espacio libre de una caja `CEMENTERIO`; no se pueden devolver al equipo. Si todo el equipo cae, la partida Nuzlocke queda marcada como fallida sin bloquear el guardado.

## Random

El asistente permite configurar:

- Progresión de fuerza según medallas.
- Movimientos, evoluciones y evoluciones con fuerza base similar.
- Compatibilidad con MT, tipos y habilidades.
- Objetos del mapa y objetos equipados.
- Recompensas aleatorias de entrenadores.
- Modo Semi Random.
- Generaciones permitidas, de la 1 a la 9.

La selección de generaciones se aplica antes de generar los iniciales. Debe quedar al menos una generación activa.

Al recoger un objeto del suelo o recibirlo de un evento o recompensa, se conservan los mensajes normales del juego y después aparece otra ventana con su descripción localizada. La ventana solo se muestra si el objeto entra en la mochila, una sola vez aunque haya varias unidades y, con Random, utiliza el objeto final obtenido tras la sustitución.

## Archivos configurables

- `Config/rules.rb`: valores predeterminados, reglas obligatorias y topes de nivel.
- `Config/areas.rb`: agrupación de mapas en zonas de captura.
- `Config/profiles.rb`: ediciones compatibles y validación del perfil.
- `Config/install_profile.rb`: idioma y perfil elegidos para la instalación.
- `Locales/*.rb`: textos en español, inglés y francés.
- `nuzlocke.log`: registro de carga, validación y errores del módulo.

La lógica del mod permanece separada en `Mods/HardcoreNuzlocke`. `preload.rb` carga el módulo antes de los scripts del juego; el módulo instala un hook diferido en `Graphics.update`, espera a que existan todas las clases y entonces instala sus hooks en memoria. Las instalaciones españolas que ya contienen el puente persistente compatible lo reutilizan.

La instalación distribuida no modifica `Data/Scripts.rxdata`. El instalador crea copias recuperables de `preload.rb` y `mkxp.json`, activa la precarga cuando la edición la trae comentada y elimina el wrapper Zlib defectuoso conocido de 2.12/2.13.

## Control de pruebas por fichero

El puente interactivo solo se activa al iniciar `Game.exe` con la variable de entorno `PZN_TEST_CONTROL=1`; una partida normal no acepta órdenes externas. Con el puente activo, escribe una orden por línea en `Mods/HardcoreNuzlocke/test-input.txt`. El juego consume y elimina el fichero y publica el resultado en `Mods/HardcoreNuzlocke/test-input.ack`.

Órdenes disponibles:

- Teclas lógicas: `UP`, `DOWN`, `LEFT`, `RIGHT`, `A`, `B`, `C`, `L`, `R`, `X`, `Y`, `Z`, `ENTER` y `ESC`.
- `HOLD DIRECCION N`: mantiene `UP`, `DOWN`, `LEFT` o `RIGHT` durante N fotogramas; permite caminar por el mapa y provocar combates reales.
- `WAIT N`: espera N fotogramas antes de continuar la secuencia.
- `TEXT texto`: introduce texto por la ruta de teclado del juego.
- Aperturas de prueba: `OPEN TYPE_CHART`, `OPEN CHALLENGES`, `OPEN RANDOM`, `OPEN NUZLOCKE`, `OPEN LEARNING`, `OPEN MOVE_INFO`, `OPEN ITEM_PICKUP`, `OPEN ITEM_RECEIVE`, `OPEN ENCOUNTER_TEST`, `OPEN OPTIONS`, `OPEN PAUSE`, `OPEN INITIAL_FLOW` y `OPEN BATTLE`. `ITEM_PICKUP` encuentra un Antídoto y `ITEM_RECEIVE` entrega una Poción en la sesión de prueba para comprobar ambos mensajes originales y sus ventanas posteriores con la descripción; `ENCOUNTER_TEST` valida que un combate por pasos no se clasifique como estático; `PAUSE` abre el menú de pausa real; `INITIAL_FLOW` simula el encadenado inicial y restaura después el estado del guardado; `BATTLE` inicia un combate salvaje real para validar los hooks de combate sin tener que recorrer el mapa.
