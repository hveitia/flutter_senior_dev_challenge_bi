# Monitoreo en producción

Cómo se sabría que la aplicación falla o que la experiencia empeora, y con qué se diagnosticaría. Primera versión: describe la base instalada en la etapa 3 y lo que se añadirá sobre ella.

Cada apartado separa lo **implementado** de lo **planificado**. La aplicación ya se ejecutó en un emulador y en un teléfono contra el proyecto real, pero **nada de lo descrito se ha observado todavía en la consola de Firebase**: no se comprobó que los eventos y los informes llegaran.

## Qué hay instalado hoy

«Implementado» puede significar dos cosas distintas, y aquí se separan: lo que **la aplicación en ejecución ya emite** y lo que **existe y está probado en la biblioteca, pero ningún código de la aplicación usa todavía**.

**Emitido por la aplicación en ejecución** ([ADR 0010](../adr/0010-observabilidad.md)):

- **Errores del framework**, enviados a Crashlytics como graves.
- **Errores asíncronos no capturados**, como no graves salvo memoria agotada o desbordamiento de pila.
- **Errores de los Blocs**, con el tipo del Bloc, el tipo del error y la traza de la pila, sin su mensaje. Cubre los Blocs del acceso: sesión, inicio de sesión y registro.
- **Rastro previo a un fallo:** los registros desde el nivel `info`.
- La recogida de fallos solo está activa en compilaciones de publicación.
- **Eventos del acceso** ([ADR 0011](../adr/0011-autenticacion-y-perfil.md)), sin ningún dato personal:

| Nombre | Cuándo se emite | Datos |
|---|---|---|
| `auth_session_restored` | Al arrancar, cuando se sabe si había sesión | Resultado: `signed_out`, `active`, `profile_incomplete` o `unavailable` |
| `auth_sign_up_step_completed` | El cliente supera un paso del registro | Número de paso |
| `auth_sign_up_interests_skipped` | El cliente omite el paso de intereses | Ninguno |
| `auth_sign_up_succeeded` | Cuenta y perfil creados | Ninguno |
| `auth_sign_up_failed` | No se pudo crear la cuenta | Clase de fallo |
| `auth_profile_save_failed` | La cuenta se creó y el perfil no pudo guardarse, o falló al completarlo | Clase de fallo |
| `auth_profile_completed` | Se guardó el perfil de una cuenta que no lo tenía | Ninguno |
| `auth_sign_in_succeeded`, `auth_sign_in_failed` | Resultado de un inicio de sesión | Clase de fallo, si falló |
| `auth_password_reset_requested` | Se pidió el correo de restablecimiento | Ninguno |
| `auth_unlock_succeeded`, `auth_unlock_failed` | Resultado de la comprobación biométrica | Ninguno |
| `auth_signed_out` | El cliente cerró la sesión | Ninguno |

- **Trazas y eventos de cuentas y movimientos** ([ADR 0012](../adr/0012-lectura-de-cuentas-y-movimientos.md)), sin importes, números de cuenta, descripciones ni nombres:

| Nombre | Tipo | Cuándo se emite | Datos |
|---|---|---|---|
| `accounts_first_load` | Traza | Desde que la sesión empieza a seguir las cuentas hasta que hay algo que mostrar | Origen (`server` o `cache`) y cantidad de cuentas; o resultado `failed` si terminó sin datos |
| `movements_first_load` | Traza | Desde que se abre una cuenta hasta que hay movimientos que mostrar | Igual que la anterior |
| `accounts_data_load_failed` | Evento | Una actualización no pudo completarse | Servicio (`accounts` o `movements`) y clase de fallo (`offline`, `timeout`, `unavailable`, `unexpected`) |
| `accounts_data_retry_requested` | Evento | El cliente toca «Reintentar» | Servicio |
| `accounts_data_served_from_cache` | Evento | Un conjunto de datos se mostró desde la copia del dispositivo, una vez por escucha | Servicio y cantidad de elementos |

- **Errores inesperados de cuentas y movimientos**, con el motivo `accounts_unexpected` y solo el tipo del error.
- **Eventos de la política de resiliencia** (`resilience_timeout`, `resilience_retry`, `resilience_attempts_exhausted`) para los servicios `auth`, `profile`, `accounts` y `movements`, que ya la usan.
- **Errores inesperados del proveedor de identidad**, con el motivo `auth_unexpected` y solo el tipo del error, porque su mensaje puede citar el correo.

**Implementado en la biblioteca, aún sin emitirse.** El repositorio de configuración no se instancia todavía en la aplicación, así que sus señales no llegan hoy a Firebase. Las de la política de resiliencia sí se emiten, para el acceso:

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
| Eventos `resilience_timeout`, `resilience_retry` y `resilience_attempts_exhausted`, por servicio | El servicio responde mal aunque no haya fallos | Evento de Analytics | La aplicación los emite para acceso, cuentas y movimientos |
| Duración de `accounts_first_load` y `movements_first_load`, por origen | Cuánto tarda el cliente en ver su saldo y sus movimientos, y cuántas veces los ve desde la copia | Traza de Performance | La aplicación las emite |
| Proporción de `accounts_data_load_failed` por servicio y clase de fallo | Indisponibilidad parcial: los movimientos fallan mientras las cuentas responden, o al revés | Evento de Analytics | La aplicación emite el evento |
| Proporción de `accounts_data_served_from_cache` | Cuánto se usa la aplicación con datos guardados | Evento de Analytics | La aplicación emite el evento |
| Eventos `accounts_data_retry_requested` | Clientes que insisten ante un error: mide la fricción que deja una falla | Evento de Analytics | La aplicación emite el evento |
| Eventos de módulo con error | Indisponibilidad parcial: qué módulo falla y con qué frecuencia | Evento de Analytics | Planificada, etapa 6 |
| Transferencias en cola y su tiempo hasta enviarse | Cuánto se usa la aplicación sin conexión | Evento de Analytics | Planificada, etapa 8 |
| Abandono en el registro, por paso | Fricción en el alta: cuántos superan cada paso y cuántos omiten los intereses | Embudo de Analytics sobre `auth_sign_up_step_completed` y `auth_sign_up_succeeded` | La aplicación emite los eventos; el embudo no está configurado |
| Proporción de `auth_sign_in_failed` por clase de fallo | Distingue credenciales rechazadas de problemas de red o del proveedor | Evento de Analytics | La aplicación emite el evento |
| Eventos `auth_profile_save_failed` | Altas que quedan a medio crear. Un aumento señala un problema con Firestore o con las reglas | Evento de Analytics | La aplicación emite el evento |
| Proporción de `auth_unlock_failed` | Fricción del desbloqueo biométrico | Evento de Analytics | La aplicación emite el evento |
| Arranque de la aplicación y pantallas lentas | Rendimiento general | Performance, automático | Disponible con el SDK |

Los umbrales de la política de resiliencia (8 s de tiempo de espera, 3 s para considerar lenta una operación) se eligieron sin mediciones. Las trazas de primera carga son las que permitirán ajustarlos.

## Qué no se registra

Ninguna señal de las anteriores incluye datos del cliente. Los eventos del acceso llevan números de paso y clases de fallo, nunca el correo, el nombre, la cédula ni el celular; lo comprueban pruebas que recorren toda la telemetría del flujo. Los eventos de cuentas y movimientos llevan el servicio, la clase de fallo y cantidades de elementos; sus pruebas comparan el contenido exacto de cada evento. Los estados y los errores de los Blocs se informan por su tipo, no por su contenido, y hay pruebas que fallan si un importe, un número de cuenta o un nombre llegan a la telemetría. El detalle y sus límites están en el [ADR 0010](../adr/0010-observabilidad.md).

## Pendiente

- Configurar las alertas en la consola de Firebase y decidir quién las recibe.
- Verificar en un dispositivo que los informes, eventos y trazas llegan.
- Monitoreo del lado del servidor (API de transferencias y envío de notificaciones), que se describirá con la etapa 8.
- Subida de símbolos para leer las trazas de una compilación ofuscada.
