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
- La prueba se escribe antes que el código que verifica.
- El trabajo incompleto se integra desactivado mediante la configuración remota ([ADR 0005](0005-home-dirigido-por-configuracion.md)), no en una rama.
- Si `main` se rompe, repararlo o revertir es lo primero.
- Las versiones se marcan con etiquetas sobre `main`.

## Trade-offs

- **Se gana:** integración continua real, sin conflictos de fusión y con un historial lineal que muestra cómo se construyó la solución.
- **Se paga:** no hay revisión de pares antes de integrar. Se compensa con la verificación automática previa a cada commit y con una revisión independiente asistida por IA de cada etapa antes de subirla al repositorio remoto. Los hallazgos de cada revisión quedan anotados en el [registro de uso de IA](../ia/registro-uso-ia.md).
- **Se paga:** el hook añade tiempo a cada commit. Con el modo acotado, un commit de documentación tarda unos 4 s, uno en un paquete de dominio unos 16 s, y uno en el sistema de diseño o en la configuración común más de 30 s, porque ejecuta casi todo (medido en la máquina de desarrollo con unas 1000 pruebas).
- **Se paga:** la selección de pruebas es código que puede equivocarse. Si omite un paquete afectado, el error llega a `main` en local y lo detecta la integración continua en el push, no el hook.
- **Se paga:** no se puede preparar solo una parte de un archivo. El script verifica el directorio de trabajo, y durante la etapa 5 eso dejó pasar un commit cuyo contenido no compilaba por sí solo, porque el archivo que le faltaba ya existía en disco sin estar preparado. El hook exige ahora que ambos coincidan; lo que no entra en el commit se aparta con `git stash`.
- **Se paga:** exigir que el directorio de trabajo coincida con el commit también impide dividir en varios commits un cambio que ya está escrito en varios paquetes, salvo apartando archivos. En la corrección de la etapa 6 eso produjo algún commit que reúne varios puntos de la revisión; se listan en su mensaje.
- **Corregido:** el hook fallaba en una copia de trabajo enlazada (`git worktree`), que es como se construyó la consola en paralelo con la etapa 6. Git exporta a sus hooks variables que apuntan al repositorio principal, y la herramienta de Flutter las tomaba por las de su propio SDK y dejaba de resolver dependencias. El hook lee ahora lo que necesita de git, borra esas variables y entrega al script la lista de archivos preparados.
- **Añadido:** la consola web, que no es un paquete de Dart, se verifica con el mismo script: siempre en el modo completo, y en el hook cuando cambian ella o el contrato. Si sus dependencias no están instaladas, el script lo dice y sigue; su propio flujo de integración continua la verifica en cada push.
- **Limitación:** la integración continua cancela las ejecuciones en curso cuando llega un push nuevo, por lo que no todos los commits intermedios quedan verificados en el servidor. En local, el hook verifica en cada uno lo que ese commit afecta.

## Impacto a largo plazo

Con un equipo, el flujo pasa a la opción 3 sin cambiar las herramientas: ramas de menos de un día, pull request con la misma verificación en verde y revisión de una persona. La regla de integrar trabajo incompleto detrás de configuración ya está en la arquitectura.

Convendría revisar la decisión en cuanto haya más de un autor, o si la verificación local, ya acotada a los paquetes afectados, vuelve a superar el tiempo que un desarrollador está dispuesto a esperar por commit; en ese caso el hook se reduciría a formato y análisis, y las pruebas quedarían en la integración continua.
