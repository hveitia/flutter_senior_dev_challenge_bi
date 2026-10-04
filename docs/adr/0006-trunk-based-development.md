# 0006. Trunk Based Development con commits directos a `main`

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** vigente desde el primer commit. Existen el hook `pre-commit`, el script `tool/verify.sh` y el flujo de integración continua.

## Problema a resolver

La prueba exige Trunk Based Development y evalúa la frecuencia de los commits y la calidad del historial. Hace falta un flujo que mantenga una única rama siempre desplegable e integre trabajo en pasos pequeños, con un único autor y sin revisión de pares disponible.

## Alternativas evaluadas

1. **GitFlow.** Ramas `develop`, de funcionalidad y de versión. Es lo contrario de lo solicitado: retrasa la integración y multiplica las ramas de larga vida.
2. **Ramas de funcionalidad con pull request.** Habitual y con revisión. Con ramas que duran días deja de ser desarrollo basado en tronco, y con un solo autor el pull request no aporta una revisión real.
3. **Tronco con ramas de vida corta.** Ramas de menos de un día integradas mediante pull request con verificación automática. Es la forma recomendada para equipos.
4. **Tronco con commits directos a `main`.** La integración es inmediata. Exige que la verificación ocurra antes de cada commit, porque no hay una etapa intermedia.

## Opción seleccionada

La opción 4, apoyada en tres mecanismos:

- **`tool/verify.sh`** es la única definición de "verde": formato, análisis estático y pruebas de todo el workspace. Con `--affected` mantiene el formato y el análisis de todo el repositorio y limita las pruebas a los paquetes que tocan los cambios preparados y a los que dependen de ellos, leyendo las dependencias de cada `pubspec.yaml`.
- **El hook `pre-commit`** ejecuta ese script en modo acotado y bloquea el commit si falla. Antes comprueba que el directorio de trabajo coincide con lo que se confirma: rechaza el commit si hay cambios sin preparar o archivos sin seguimiento en las carpetas de código.
- **La integración continua** ejecuta el script completo en cada push a `main`. Es la puerta que decide si `main` está en verde.

**Por qué acotar el hook no debilita la garantía.** Un paquete que el commit no toca, y que no depende de nada que el commit toque, no puede cambiar de comportamiento: sus pruebas darían el mismo resultado que en el commit anterior, que ya estaba en verde. El grafo de dependencias se lee de los `pubspec.yaml`, que son los que el compilador respeta; un cambio en la configuración común ejecuta todo. Lo que el análisis de dependencias no ve (un contrato leído como archivo, por ejemplo) se declara de forma explícita en el script, y la integración continua cubre cualquier omisión en el push siguiente.

Reglas de trabajo:

- Commits pequeños y atómicos, con mensajes en formato Conventional Commits.
- La prueba se escribe antes que el código que verifica. La regla no se cumplió siempre: en la primera versión de varias etapas las pruebas se escribieron junto con el código, y se cumplió de forma estricta en las correcciones, donde cada defecto se reprodujo con una prueba que fallaba antes de arreglarlo ([alcance y riesgos](../alcance-y-riesgos.md)).
- El trabajo incompleto se integra desactivado mediante la configuración remota ([ADR 0005](0005-home-dirigido-por-configuracion.md)), no en una rama.
- Si `main` se rompe, repararlo o revertir es lo primero.
- La versión entregada se marca con una etiqueta sobre `main`: `v0.1.0`, de la que sale la publicación con el instalador de Android. Durante el desarrollo no se creó ninguna otra.

**Cómo se ve el historial y por qué.** Son más de 280 commits en dos días, de un solo autor y sin commits de fusión.

- **Cadencia.** Cada commit se verificó en local con el hook. Los commits se subieron por lotes, uno por etapa o por corrección, después de una revisión independiente; la integración continua corrió en cada subida, no en cada commit.
- **Ejecuciones canceladas.** Cuando una subida llegó mientras la anterior seguía en verificación, la integración continua canceló la anterior. Esas ejecuciones aparecen como canceladas, no como fallidas, y la siguiente incluye sus commits.
- **Etapas en paralelo.** Algunas etapas se construyeron a la vez en copias de trabajo aisladas (`git worktree`) y se integraron reubicando sus commits sobre `main` y avanzando sin fusión, de modo que el historial sigue siendo lineal.
- **Commits grandes.** Los mayores son archivos generados (los archivos de bloqueo de dependencias de npm y de Dart). Otros reúnen un paquete entero o varios puntos de una revisión, porque el hook exige que el directorio de trabajo coincida con el commit y dividir un cambio ya escrito obligaba a apartar archivos. Es un costo de esa regla, descrito más abajo.
- **Reparaciones antes de publicar.** Dos veces un lote local tuvo commits intermedios defectuosos: uno que no compilaba por sí solo (etapa 5) y varios que dejaban una prueba en rojo tras reubicar una etapa construida en paralelo. En ambos casos se corrigieron esos commits antes de subirlos, cuando aún eran historial local, comprobando que el contenido final no cambiaba.

## Trade-offs

- **Se gana:** integración continua real, sin conflictos de fusión y con un historial lineal que muestra cómo se construyó la solución.
- **Se paga:** no hay revisión de pares antes de integrar. Se compensa con la verificación automática previa a cada commit y con una revisión independiente asistida por IA de cada etapa antes de subirla al repositorio remoto. Las correcciones que salieron de cada revisión están en el historial de `main`, y el método se resume en el [uso de IA en el desarrollo](../ia/registro-uso-ia.md).
- **Se paga:** el hook añade tiempo a cada commit. Con el modo acotado y las pruebas actuales, un commit de documentación tarda unos 7 s y uno en un paquete del que dependen otros cinco, unos 47 s, porque ejecuta también los dependientes (medido en una copia limpia del repositorio).
- **Se paga:** la selección de pruebas es código que puede equivocarse. Si omite un paquete afectado, el error llega a `main` en local y lo detecta la integración continua en el push, no el hook.
- **Se paga:** no se puede preparar solo una parte de un archivo. El script verifica el directorio de trabajo, y durante la etapa 5 eso dejó pasar un commit cuyo contenido no compilaba por sí solo, porque el archivo que le faltaba ya existía en disco sin estar preparado. El hook exige ahora que ambos coincidan; lo que no entra en el commit se aparta con `git stash`.
- **Se paga:** exigir que el directorio de trabajo coincida con el commit también impide dividir en varios commits un cambio que ya está escrito en varios paquetes, salvo apartando archivos. En la corrección de la etapa 6 eso produjo algún commit que reúne varios puntos de la revisión; se listan en su mensaje.
- **Corregido:** el hook fallaba en una copia de trabajo enlazada (`git worktree`), que es como se construyó la consola en paralelo con la etapa 6. Git exporta a sus hooks variables que apuntan al repositorio principal, y la herramienta de Flutter las tomaba por las de su propio SDK y dejaba de resolver dependencias. El hook lee ahora lo que necesita de git, borra esas variables y entrega al script la lista de archivos preparados.
- **Añadido:** la consola web, que no es un paquete de Dart, se verifica con el mismo script: siempre en el modo completo, y en el hook cuando cambian ella o el contrato. Dejarla fuera es siempre una decisión escrita: el modo completo falla si sus dependencias no están instaladas, el trabajo de integración continua del workspace la excluye de forma explícita (`--without-console`) porque la consola tiene su propio flujo, que la verifica cuando cambian ella o el contrato, y solo el hook puede seguir sin ellas, avisándolo.
- **Limitación:** la integración continua cancela las ejecuciones en curso cuando llega un push nuevo, por lo que no todos los commits intermedios quedan verificados en el servidor. En local, el hook verifica en cada uno lo que ese commit afecta.

## Impacto a largo plazo

Con un equipo, el flujo pasa a la opción 3 sin cambiar las herramientas: ramas de menos de un día, pull request con la misma verificación en verde y revisión de una persona. La regla de integrar trabajo incompleto detrás de configuración ya está en la arquitectura.

Convendría revisar la decisión en cuanto haya más de un autor, o si la verificación local, ya acotada a los paquetes afectados, vuelve a superar el tiempo que un desarrollador está dispuesto a esperar por commit; en ese caso el hook se reduciría a formato y análisis, y las pruebas quedarían en la integración continua.
