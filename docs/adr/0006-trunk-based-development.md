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

- **`tool/verify.sh`** es la única definición de "verde": formato, análisis estático y pruebas de todo el workspace.
- **El hook `pre-commit`** ejecuta ese script y bloquea el commit si falla. Antes comprueba que el directorio de trabajo coincide con lo que se confirma: rechaza el commit si hay cambios sin preparar o archivos sin seguimiento en las carpetas de código.
- **La integración continua** ejecuta el mismo script en cada push a `main`.

Reglas de trabajo:

- Commits pequeños y atómicos, con mensajes en formato Conventional Commits.
- La prueba se escribe antes que el código que verifica.
- El trabajo incompleto se integra desactivado mediante la configuración remota ([ADR 0005](0005-home-dirigido-por-configuracion.md)), no en una rama.
- Si `main` se rompe, repararlo o revertir es lo primero.
- Las versiones se marcan con etiquetas sobre `main`.

## Trade-offs

- **Se gana:** integración continua real, sin conflictos de fusión y con un historial lineal que muestra cómo se construyó la solución.
- **Se paga:** no hay revisión de pares antes de integrar. Se compensa con la verificación automática previa a cada commit y con una revisión independiente asistida por IA de cada etapa antes de subirla al repositorio remoto. Los hallazgos de cada revisión quedan anotados en el [registro de uso de IA](../ia/registro-uso-ia.md).
- **Se paga:** el hook añade unos segundos a cada commit, y ese tiempo crecerá con el número de pruebas.
- **Se paga:** no se puede preparar solo una parte de un archivo. El script verifica el directorio de trabajo, y durante la etapa 5 eso dejó pasar un commit cuyo contenido no compilaba por sí solo, porque el archivo que le faltaba ya existía en disco sin estar preparado. El hook exige ahora que ambos coincidan; lo que no entra en el commit se aparta con `git stash`.
- **Limitación:** la integración continua cancela las ejecuciones en curso cuando llega un push nuevo, por lo que no todos los commits intermedios quedan verificados en el servidor. Todos lo están en local por el hook.

## Impacto a largo plazo

Con un equipo, el flujo pasa a la opción 3 sin cambiar las herramientas: ramas de menos de un día, pull request con la misma verificación en verde y revisión de una persona. La regla de integrar trabajo incompleto detrás de configuración ya está en la arquitectura.

Convendría revisar la decisión en cuanto haya más de un autor, o si la verificación local supera el tiempo que un desarrollador está dispuesto a esperar por commit; en ese caso el hook se limita a los paquetes afectados y la verificación completa queda en la integración continua.
