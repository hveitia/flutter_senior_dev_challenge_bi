# Monitoreo en producción

Cómo se sabría que la aplicación falla o que la experiencia empeora, y con qué se diagnosticaría. Primera versión: describe la base instalada en la etapa 3 y lo que se añadirá sobre ella.

Cada apartado separa lo **implementado** de lo **planificado**. Nada de lo descrito se ha observado todavía en la consola de Firebase, porque la aplicación no se ha ejecutado en un dispositivo desde que se instaló la telemetría.

## Qué hay instalado hoy

Implementado ([ADR 0010](../adr/0010-observabilidad.md)):

- **Errores no capturados.** Los errores del framework y los asíncronos sin capturar se envían a Crashlytics como graves.
- **Errores de los Blocs.** Cada error de un Bloc se informa con el tipo del Bloc, el tipo del error y la traza de la pila, sin su mensaje.
- **Rastro previo a un fallo.** Los registros desde el nivel `info` quedan como rastro en Crashlytics.
- **Versión de configuración en cada informe.** El repositorio de configuración fija `config_version` y `config_origin` como contexto. Está implementado y probado, pero el repositorio aún no se instancia en la aplicación.
- **Configuración rechazada.** Cada documento publicado que la aplicación no acepta deja un registro `config_rejected` con el motivo. Misma salvedad que el punto anterior.

Planificado, en la etapa de cada funcionalidad:

- Trazas de rendimiento con nombre.
- Eventos de producto.
- Alertas configuradas en la consola de Firebase.

## Detección de problemas operativos

| Señal | Qué indica | Fuente | Estado |
|---|---|---|---|
| Porcentaje de usuarios sin fallos | Estabilidad general. Una caída tras una publicación señala esa versión | Crashlytics | Datos disponibles; alerta planificada |
| Alerta de velocidad | Un mismo fallo afecta de pronto a muchos usuarios | Crashlytics | Planificada |
| Fallos nuevos y regresiones | Un defecto que aparece o reaparece en una versión | Crashlytics | Planificada |
| Fallos agrupados por `config_version` | Un fallo causado por una configuración publicada, no por el código | Clave personalizada | Clave implementada; sin uso todavía |
| Registros `config_rejected` | La consola publicó un documento que las aplicaciones instaladas no entienden | Rastro de Crashlytics | Implementado; sin uso todavía |
| Errores con motivo `config_source_failed` | La aplicación no puede leer la configuración (permisos, red) | Crashlytics | Implementado; sin uso todavía |

El caso que más interesa en esta arquitectura es el cuarto. La experiencia cambia sin publicar la aplicación, así que un fallo puede empezar sin que haya una versión nueva a la que atribuirlo. Con la versión de configuración en cada informe, la pregunta «¿qué cambió?» tiene respuesta: se compara la versión de configuración de los informes anteriores y posteriores al inicio del problema, y la consola permite volver a publicar la anterior.

## Detección de problemas de experiencia

Un fallo es visible. Una pantalla que tarda, un reintento constante o un módulo que no carga no lo son, salvo que se midan.

| Señal | Qué indica | Fuente | Estado |
|---|---|---|---|
| Duración de `home_load` | Cuánto tarda el inicio en ser útil, por origen de datos (red o caché) | Traza de Performance | Planificada, etapa 6 |
| Duración de `transfer_submit` | Latencia de la operación más sensible | Traza de Performance | Planificada, etapa 8 |
| Eventos de reintento y de intentos agotados | El servicio responde mal aunque no haya fallos | Evento de Analytics | Planificada, etapa 5 |
| Eventos de módulo con error | Indisponibilidad parcial: qué módulo falla y con qué frecuencia | Evento de Analytics | Planificada, etapa 6 |
| Transferencias en cola y su tiempo hasta enviarse | Cuánto se usa la aplicación sin conexión | Evento de Analytics | Planificada, etapa 8 |
| Abandono en el registro, por paso | Fricción en el alta | Embudo de Analytics | Planificada, etapa 4 |
| Arranque de la aplicación y pantallas lentas | Rendimiento general | Performance, automático | Disponible con el SDK |

Los umbrales de la política de resiliencia (8 s de tiempo de espera, 3 s para considerar lenta una operación) se eligieron sin mediciones. Las dos primeras trazas son las que permitirán ajustarlos.

## Qué no se registra

Ninguna señal de las anteriores incluye datos del cliente. Los estados y los errores de los Blocs se informan por su tipo, no por su contenido, y hay pruebas que fallan si un importe, un número de cuenta o un nombre llegan a la telemetría. El detalle y sus límites están en el [ADR 0010](../adr/0010-observabilidad.md).

## Pendiente

- Configurar las alertas en la consola de Firebase y decidir quién las recibe.
- Verificar en un dispositivo que los informes, eventos y trazas llegan.
- Monitoreo del lado del servidor (API de transferencias y envío de notificaciones), que se describirá con la etapa 8.
- Subida de símbolos para leer las trazas de una compilación ofuscada.
