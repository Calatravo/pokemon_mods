# Habilidades aleatorias de las megas

En el código publicado hasta 1.1.7 se ha confirmado una excepción de Mega
Lopunny y Mega Abomasnow: sus definiciones usan el antiguo callback `ability`
para devolver la habilidad canónica. Esto evita la consulta de la lista
aleatoria y también afecta a la habilidad efectiva del combatiente tras
megaevolucionar. No es solo un texto de la ficha ni una coincidencia del sorteo.

Mega Venusaur y las dos megas de Charizard usan listas de habilidades y no
presentan esa excepción en las pruebas realizadas.

## Corrección incluida en 1.1.8

- Full Random asigna y conserva una tabla para la forma mega, separada de la
  forma normal cuando está activada la configuración de habilidades por forma.
- Mapeo consistente aplica el mismo reemplazo a la habilidad canónica de la
  mega que a cualquier otra aparición de esa habilidad.
- Sin randomizar, Semi Random y Random desactivado conservan la habilidad
  canónica.
- Las tablas válidas ya guardadas no se vuelven a sortear. Al terminar la
  megaevolución se recupera la habilidad guardada de la forma normal.
- La ficha, la lista de habilidades y el combatiente consultan el mismo
  resultado. Una habilidad aleatoria aún puede coincidir con la canónica;
  no se prohíbe esa coincidencia.

El arreglo reutiliza los datos aleatorios del guardado y no requiere desbloquear
la configuración ni comenzar otra partida. Al actualizar una run Full Random,
la habilidad efectiva de estas megas puede cambiar: se usará la asignación válida
de su forma mega o se generará una si no existía. En mapeo se reutiliza el
reemplazo de la habilidad canónica, creándolo solo si falta. Las formas normales
conservan sus habilidades guardadas y las recuperan al dejar de ser mega.

## Comprobación

`pwsh -File tests/mega_abilities_integration.ps1 -GameFolder <carpeta>` carga
los scripts y datos reales y ejecuta la función nativa de megaevolución en
ambos lados del combate. Solo se sustituyen las animaciones, mensajes y cambios
gráficos. No se ejecuta Main ni se escriben partidas.

Cubre Lopunny, Abomasnow, Venusaur y Charizard X/Y; Full Random, mapeo,
configuración compartida de formas, modos desactivados, índices de habilidades,
retorno a la forma normal, recarga de tablas en memoria y reparación de tablas
inválidas. Con `-Unpatched` se reproduce el fallo de 1.1.7.
