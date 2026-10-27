# Protección selectiva de objetos random

La lista `RandomizedChallenge::UNRANDOMIZABLE_ITEMS` del juego base no se
restaura entera: incluye materiales, bayas y equipo que deben poder cambiar
en recogidas únicas y regalos ordinarios. `ITEM_BLACK_LIST` es independiente:
filtra los posibles resultados aleatorios, no protege el objeto entregado.

## Criterio implementado

- Conservar objetos del bolsillo 8, objetos de tipo clave, MO y megapiedras.
- Conservar llaves, tickets, monedas de acceso y las excepciones concretas de
  misión indicadas abajo, incluso si una edición no los marca como clave.
- Conservar Polvo Brillante y Brasa Candente para el tutorial y la reposición
  de Olivier. La protección funciona tanto con `pbReceiveItem` como con
  `pbItemBall`.
- Conservar las entregas de nodos de recursos ya reconocidos por el mod.
- Permitir randomizar el resto de recogidas únicas y regalos: por ejemplo,
  Mini Seta, Madera, Baya Zidra y Amuleto Fuego, aunque estén en la lista original.
- Si una recompensa randomizada debe dar una MT, elegir directamente entre las
  MT que faltan. Solo sustituirla por un objeto común si ya están todas.

## Selección de MT

El selector original prueba MT al azar un número limitado de veces. Si todos
los intentos coinciden con MT de la mochila, entrega un objeto ordinario aunque
todavía falten MT. Además, reutiliza sin comprobar la lista `tm_list` del guardado:
si está incompleta y sus entradas ya se poseen, no encuentra las demás MT.

El mod reconstruye esa lista a partir de los datos de la edición y selecciona
entre las MT ausentes, sin intentos fallidos. Esto se aplica al selector compartido
por recogidas, recompensas y tiendas. Conserva las MT obtenidas y los movimientos
asignados. Las recompensas ya consumidas no se restauran automáticamente;
las partidas antiguas disponen de la compensación opcional descrita abajo.

Estas dos condiciones se han reproducido con datos del juego. Sin el guardado
del reporte no se ha confirmado qué condición afecta a ese jugador ni un cambio
específico al entrar en el acto 2. Una NPC que entrega Carantoña requiere su
ubicación para distinguir una recompensa normal de una randomizada.

Los nodos con gráfico `guijarros` de Gruta Helada entregan `GUIJARRO` en los
eventos revisados y conservan ese recurso por diseño. El `NEVERMELTICE` del
mapa 243, evento 8, es una recogida de una sola vez con gráfico `objeto`;
no se ha identificado todavía qué piedras describe el reporte de Antiderretir.

## Compensación para partidas antiguas

En **Desafíos → Compensar MT perdidas**, una partida que ya había activado
Random antes del arreglo puede solicitar una única compensación. El jugador
indica cuántas MT perdió, confirma la cantidad y recibe ese número de MT
aleatorias que todavía no posee. No se entregan automáticamente todas las MT
que falten: muchas pueden corresponder a contenido aún no visitado.

El guardado no registra cada sustitución histórica ni el resultado aleatorio que
habría correspondido. Por eso la cantidad es manual y la opción explica que es
una compensación, no una restauración exacta. Las runs que activen Random con
el arreglo ya instalado no disponen de esta opción.

Se conservan las MT y asignaciones de movimientos existentes. Las nuevas
asignaciones respetan la progresividad y se eligen sin bucles de reintento
ilimitados. Una mochila sin espacio o un error revierte la entrega completa y
no consume el uso. Al guardar se conservan tanto las MT como el registro del
uso único; cancelar o rechazar no altera la partida. No se reactivan eventos
completados ni se fuerza un guardado.

El usuario ha confirmado mod **1.1.4**, Pokémon Z **ES 2.18** y **Kirin en móvil**.
La compensación se valida con el Ruby y los datos de esa edición en PC; eso no
equivale a una comprobación en su dispositivo Kirin. La corrección y la
compensación se incluyen en la release 1.1.6.

## Contraste con la guía y los eventos

Fuente: *Guía Oficial de Pokémon Z*, PDF de 559 páginas facilitado por el usuario.
Los números siguientes son páginas del PDF. Los eventos se comprobaron en los
datos locales del juego; la guía orienta la revisión, pero no sustituye al código.

| Caso | Guía | Implementación y protección |
| --- | --- | --- |
| Pokévial, Pokébrújula y Pokérider | 12 | Bolsillo de objetos clave. |
| Caña de pescar | 14 | Las tres cañas están en el bolsillo 8 y son de tipo clave. |
| Tutorial de Polvo Explosivo | 18 | Mapa 16, eventos 16/25/26: ingredientes; evento 17: reposición por `pbItemBall`. Excepción explícita para los dos ingredientes. |
| Monedas del barquero | 103, 107, 111 | `MONEDAPLATA`; Zafra y Mirra, mapa 113, eventos 23/24. Protegidas por grupo y bolsillo. |
| Fuga de prisión | 205-206 | `ITEMPRISION1/2/3`: objetos especiales de misión, no la baya y piedra ordinarias. Bolsillo 8 también en EN/FR. |
| Reparación de F3 | 219 | La batería del mapa 255, evento 40, cambia la variable 181; no entrega un objeto randomizable. `CABEZAF3` sí es un objeto del bolsillo 8. |
| Reclutamiento de Andrea | 438-439 | `HERRAMIENTAS`: recogida única en mapa 337, evento 7, requerida en mapa 241, evento 5. Excepción explícita. |
| Mew y Mewtwo | 462 | `GENMISTERIOSO`: entrega por `pbItemBall` en mapa 433, evento 4, página 2. Ingrediente de `EMBRIONM`, requerido en el laboratorio. Excepciones explícitas para ambos. |
| Volcanion | 474 | `BATERIAVOLCANION`: Clem consume ingredientes y completa el encargo; se requiere la batería en mapa 464, evento 1. Excepción explícita. |

Al comparar todos los objetos clave de ES 2.18 con los datos compilados de
EN 2.13 y FR 2.12, cuatro pierden tanto el bolsillo 8 como el tipo clave:
`HERRAMIENTAS`, `BATERIAVOLCANION`, `EMBRIONM` y `GENMISTERIOSO`.
Las excepciones explícitas cubren esas diferencias sin excluir categorías
enteras de materiales.

## Validación

`ruby --disable-gems tests/item_randomization_test.rb` comprueba regalos y
recogidas, símbolos/texto/IDs, claves con metadatos incompletos, reposición de
Olivier y objetos ordinarios que deben seguir randomizándose. La prueba
`ITEM_POLICY_TEST` usa Mini Seta como ejemplo de exclusión original no esencial.

`pwsh -File tests/tm_randomization_integration.ps1 -GameFolder <carpeta>` usa el
Ruby 1.8.7 y los datos reales de cada edición: selección de la última MT que
falta, reparación de una lista guardada incompleta con solo 12 MT obtenidas,
entregas por ambas rutas con 0/4/8 medallas, movimientos guardados, recursos
renovables y agotamiento real del catálogo. Con `-Unpatched` se reproduce el
fallo original de sustituir la última MT pendiente por un objeto común.

La misma prueba ejecuta `tests/tm_recovery_test.rb`: cantidad manual, exclusión
de MT poseídas y partidas nuevas, movimientos conservados, progresividad,
uso único tras recarga en memoria, cancelación/confirmación del menú,
restauración ante escrituras parciales y textos en los tres idiomas.

La revisión y las pruebas aisladas no equivalen a completar una partida en
cada edición. No se modifican los mapas, scripts originales ni partidas.
