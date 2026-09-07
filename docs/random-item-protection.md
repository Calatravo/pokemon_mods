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

La revisión y las pruebas aisladas no equivalen a completar una partida en
cada edición. No se modifican los mapas, scripts originales ni partidas.
