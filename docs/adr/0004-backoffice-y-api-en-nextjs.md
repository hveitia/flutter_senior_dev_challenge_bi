# 0004. Consola web y API de servidor en Next.js

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** planificada. `apps/backoffice` todavía no existe.

## Problema a resolver

Hacen falta tres capacidades que no pueden vivir en la aplicación móvil:

1. Una herramienta para cambiar la experiencia de la aplicación (módulos del inicio, funcionalidades, contenido) y ver el cambio reflejado sin publicar una versión nueva.
2. Enviar notificaciones push. El envío requiere credenciales de servicio que no pueden distribuirse en un cliente.
3. Ejecutar transferencias. Un cliente no debe escribir saldos: la operación tiene que validarse y aplicarse en un servidor.

## Alternativas evaluadas

1. **Consola en Flutter Web con Cloud Functions.** Comparte modelos Dart con la aplicación. El envío de push y las transferencias necesitarían Cloud Functions, que exigen un plan de pago, y Flutter Web es una base poco habitual para una herramienta interna.
2. **Solo la consola de Firebase.** No requiere construir nada. No permite mostrar la experiencia de edición ni la vista previa, y no resuelve la ejecución de transferencias.
3. **Next.js con rutas de servidor.** Una sola aplicación ofrece la consola y la API. Las rutas de servidor usan el SDK de administración con credenciales que nunca salen del servidor. Introduce un segundo lenguaje y un segundo conjunto de herramientas.

## Opción seleccionada

La opción 3: Next.js, dentro del mismo monorepo, con dos responsabilidades.

- **Consola de una sola pantalla:** segmentos, orden y visibilidad de los módulos del inicio, banner promocional, funcionalidades, laboratorio de resiliencia para la demostración, envío de notificaciones y vista previa.
- **API de servidor:** publicación de la configuración, envío de push y ejecución de transferencias. Verifica el token de identidad del usuario antes de operar.

Esta decisión corrige una propuesta inicial. La primera recomendación fue Flutter Web, para compartir modelos con la aplicación. El autor eligió Next.js por ser más realista para una herramienta interna, y el análisis posterior lo respaldó: el envío de push exige un servidor de todas formas, y una aplicación ya instalada puede quedar desfasada respecto de la consola aunque compartan código, por lo que la aplicación debe tolerar configuración desconocida en cualquier caso.

## Trade-offs

- **Se gana:** la lógica sensible se ejecuta en el servidor sin infraestructura adicional ni plan de pago.
- **Se gana:** coherencia con un ecosistema de equipos independientes, donde cada dominio elige la tecnología adecuada.
- **Se paga:** dos lenguajes, dos conjuntos de herramientas y dos flujos de integración continua.
- **Se paga:** el contrato de configuración deja de estar garantizado por el compilador. Se mitiga con un contrato versionado en `contracts/` como única fuente de verdad: la consola valida antes de publicar y la aplicación interpreta de forma defensiva ([ADR 0005](0005-home-dirigido-por-configuracion.md)).

## Impacto a largo plazo

La API de servidor es el punto donde se sustituirían las operaciones de demostración por llamadas a sistemas bancarios reales, sin cambiar la aplicación móvil. La consola puede crecer hacia autenticación de operadores, roles y auditoría, que quedan fuera del alcance actual de forma deliberada.

Convendría revisar la decisión si la API crece hasta necesitar un ciclo de vida distinto al de la consola; en ese caso se separan en dos despliegues.
