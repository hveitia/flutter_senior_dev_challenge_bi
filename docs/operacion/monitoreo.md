# Monitoreo en producción

Cómo se sabría que la aplicación falla o que la experiencia empeora, y con qué se diagnosticaría. Primera versión: describe la base instalada en la etapa 3 y lo que se añadirá sobre ella.

Cada apartado separa lo **implementado** de lo **planificado**. Nada de lo descrito se ha observado todavía en la consola de Firebase, porque la aplicación no se ha ejecutado en un dispositivo desde que se instaló la telemetría.

## Qué hay instalado hoy

«Implementado» puede significar dos cosas distintas, y aquí se separan: lo que **la aplicación en ejecución ya emite** y lo que **existe y está probado en la biblioteca, pero ningún código de la aplicación usa todavía**.

**Emitido por la aplicación en ejecución** ([ADR 0010](../adr/0010-observabilidad.md)):

- **Errores del framework**, enviados a Crashlytics como graves.
- **Errores asíncronos no capturados**, como no graves salvo memoria agotada o desbordamiento de pila.
- **Errores de los Blocs**, con el tipo del Bloc, el tipo del error y la traza de la pila, sin su mensaje. Hoy la aplicación no tiene ningún Bloc propio; el observador está instalado para los que lleguen.
- **Rastro previo a un fallo:** los registros desde el nivel `info`.
- La recogida de fallos solo está activa en compilaciones de publicación.

**Implementado en la biblioteca, aún sin emitirse.** El repositorio de configuración y la política de resiliencia no se instancian todavía en la aplicación, así que nada de esta lista llega hoy a Firebase:

| Nombre | Tipo | Cuándo se emite | Datos |
|---|---|---|---|
| `config_version`, `config_origin` | Contexto | En cada configuración aplicada | Versión y origen (`remote`, `cached`, `bundled`, `lastResort`) |
| `config_applied` | Evento | En cada configuración aplicada | Origen y versión |
| `config_rejected` | Evento | Un documento publicado no se acepta | Motivo |
| `config_cache_invalid` | Evento | El documento guardado en el dispositivo ya no es válido | Motivo |
| `config_bundled_invalid` | Evento, y error si el recurso no pudo cargarse | El documento incluido en la aplicación no puede leerse; se usa el de último recurso | Motivo |
| `config_source_failed` | Evento, y error si la fuente falló | La fuente remota falla o se cierra | Número de fallo consecutivo y causa |
| `config_cache_failed` | Error | Falla la lectura o la escritura del almacenamiento del dispositivo | Ninguno |
| `resilience_timeout` | Evento | Un intento agota su tiempo | Servicio e intento |
| `resilience_retry` | Evento | Empieza un reintento | Servicio e intento |
| `resilience_attempts_exhausted` | Evento | Falla también el último intento permitido | Servicio e intento |
| `resilience_fault_injection_enabled` | Evento | Una compilación con la inyección de fallos permitida ejecuta su primera operación | Ninguno |

**Planificado**, en la etapa de cada funcionalidad:

- Trazas de rendimiento con nombre.
- Eventos de producto.
- Alertas configuradas en la consola de Firebase.

## Detección de problemas operativos

| Señal | Qué indica | Fuente | Estado |
|---|---|---|---|
| Porcentaje de usuarios sin fallos | Estabilidad general. Una caída tras una publicación señala esa versión | Crashlytics | La aplicación envía los errores; no se ha comprobado que lleguen. Alerta planificada |
| Alerta de velocidad | Un mismo fallo afecta de pronto a muchos usuarios | Crashlytics | Planificada |
| Fallos nuevos y regresiones | Un defecto que aparece o reaparece en una versión | Crashlytics | Planificada |
| Fallos agrupados por `config_version` | Un fallo causado por una configuración publicada, no por el código | Clave personalizada | En la biblioteca; aún no se emite |
| Eventos `config_rejected` | La consola publicó un documento que las aplicaciones instaladas no entienden | Evento de Analytics | En la biblioteca; aún no se emite |
| Eventos y errores `config_source_failed` | La aplicación no puede leer la configuración (permisos, red). El número de fallo distingue un corte puntual de uno sostenido | Analytics y Crashlytics | En la biblioteca; aún no se emite |
| Eventos `config_applied` con origen `lastResort` o `bundled` en usuarios que no son nuevos | Dispositivos que no reciben la configuración publicada | Evento de Analytics | En la biblioteca; aún no se emite |
| Cualquier evento `resilience_fault_injection_enabled` | Una compilación de demostración llegó a usuarios reales | Evento de Analytics | En la biblioteca; aún no se emite |

El caso que más interesa en esta arquitectura es el cuarto. La experiencia cambia sin publicar la aplicación, así que un fallo puede empezar sin que haya una versión nueva a la que atribuirlo. Con la versión de configuración en cada informe, la pregunta «¿qué cambió?» tiene respuesta: se compara la versión de configuración de los informes anteriores y posteriores al inicio del problema, y la consola permite volver a publicar la anterior.

## Detección de problemas de experiencia

Un fallo es visible. Una pantalla que tarda, un reintento constante o un módulo que no carga no lo son, salvo que se midan.

| Señal | Qué indica | Fuente | Estado |
|---|---|---|---|
| Duración de `home_load` | Cuánto tarda el inicio en ser útil, por origen de datos (red o caché) | Traza de Performance | Planificada, etapa 6 |
| Duración de `transfer_submit` | Latencia de la operación más sensible | Traza de Performance | Planificada, etapa 8 |
| Eventos `resilience_timeout`, `resilience_retry` y `resilience_attempts_exhausted`, por servicio | El servicio responde mal aunque no haya fallos | Evento de Analytics | En la biblioteca; se emitirán cuando un repositorio use la política (etapa 5) |
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
