# Desafíos configurables - Pokémon Z V2.18

Este módulo añade Nuzlocke forzado, Random configurable y Randomlocke. Los modos están disponibles desde la primera partida y su estado se guarda dentro de la partida.

## Inicio de una partida

La elección Nuzlocke original está disponible desde la primera partida. Después de responderla, el juego abre el asistente Nuzlocke si se eligió Sí y, a continuación, siempre pregunta si se desea activar Random. Si se responde Sí a Random, abre inmediatamente su configuración. De este modo se puede empezar en Nuzlocke, Random, Randomlocke o partida normal sin completar antes el juego.

Cada modo usa su propio asistente a pantalla completa. Al seleccionar una regla, la explicación, el efecto sobre la partida, la pregunta de activación o desactivación y los botones Sí/No se muestran juntos. La última opción es `Aplicar y continuar`.

Al aplicar un modo, su configuración queda bloqueada para ese guardado. Así no se pueden relajar las reglas a mitad de una partida.

## Acceso posterior

- Menú de opciones: `Desafíos - Abrir`.
- Menú de opciones: `Ayudas de combate - Configurar`.
- Menú de opciones: `Tabla de tipos - Abrir`.
- Menú de pausa: selecciona la nueva entrada `Desafíos`. También se conserva el atajo `S` (`R` en el sistema de entrada del juego).

Desde el centro de desafíos se puede consultar el estado de los modos, el progreso, las zonas, los encuentros perdidos y el cementerio. Una configuración ya aplicada puede revisarse, pero no alterarse.

La tabla de tipos muestra el icono y el nombre de cada tipo. Izquierda y derecha cambian de tipo; C alterna entre defensa y ataque; arriba y abajo desplazan las relaciones cuando no caben; X o Esc vuelve al menú. La distribución en tres columnas evita que tipos con muchas relaciones, como Roca, salgan de la pantalla.

## Ayudas para aprender en combate

La pantalla `Ayudas de combate` permite activar o desactivar individualmente:

- Ficha completa del ataque al pulsar X sobre él durante el combate.
- Etiquetas de eficacia en cada ataque.
- Multiplicadores exactos (`x0`, `x0.5`, `x1`, `x2` o `x4`).
- Comparación ofensiva y defensiva al recorrer el equipo durante un cambio.
- Confirmación antes de usar un ataque de daño sin efecto.
- Nombre de los tipos del rival en el selector de ataques.

La ficha de ataque usa el icono y nombre del tipo del juego y muestra categoría, potencia, precisión, PP, prioridad, eficacia contra el rival y descripción. Los movimientos de estado se identifican como tales y no reciben una etiqueta de eficacia de daño engañosa. Las ayudas habituales vienen activadas y se guardan por partida.

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

## Archivos configurables

- `Config/rules.rb`: valores predeterminados, reglas obligatorias y topes de nivel.
- `Config/areas.rb`: agrupación de mapas en zonas de captura.
- `nuzlocke.log`: registro de carga, validación y errores del módulo.

La lógica del mod permanece separada en `Mods/HardcoreNuzlocke`. `preload.rb` carga el módulo antes de los scripts del juego; el propio módulo espera a que existan todas las clases e instala un puente temporal en memoria antes de `Main`.

La instalación distribuida no modifica `Data/Scripts.rxdata`. El instalador crea una copia recuperable de `preload.rb` antes de añadir su bloque de carga.

## Control de pruebas por fichero

El puente interactivo solo se activa al iniciar `Game.exe` con la variable de entorno `PZN_TEST_CONTROL=1`; una partida normal no acepta órdenes externas. Con el puente activo, escribe una orden por línea en `Mods/HardcoreNuzlocke/test-input.txt`. El juego consume y elimina el fichero y publica el resultado en `Mods/HardcoreNuzlocke/test-input.ack`.

Órdenes disponibles:

- Teclas lógicas: `UP`, `DOWN`, `LEFT`, `RIGHT`, `A`, `B`, `C`, `L`, `R`, `X`, `Y`, `Z`, `ENTER` y `ESC`.
- `HOLD DIRECCION N`: mantiene `UP`, `DOWN`, `LEFT` o `RIGHT` durante N fotogramas; permite caminar por el mapa y provocar combates reales.
- `WAIT N`: espera N fotogramas antes de continuar la secuencia.
- `TEXT texto`: introduce texto por la ruta de teclado del juego.
- Aperturas de prueba: `OPEN TYPE_CHART`, `OPEN CHALLENGES`, `OPEN RANDOM`, `OPEN NUZLOCKE`, `OPEN LEARNING`, `OPEN MOVE_INFO`, `OPEN OPTIONS`, `OPEN INITIAL_FLOW` y `OPEN BATTLE`. `INITIAL_FLOW` simula el encadenado inicial y restaura después el estado del guardado; `BATTLE` inicia un combate salvaje real para validar los hooks de combate sin tener que recorrer el mapa.
