# Monitoreo en producción

Cómo se sabría que la aplicación falla o que la experiencia empeora, y con qué se diagnosticaría. Describe lo instalado hasta la etapa 6 y lo que se añadirá sobre ello.

Cada apartado separa lo **implementado** de lo **planificado**. La aplicación ya se ejecutó en un emulador y en un teléfono contra el proyecto real, incluidas las transferencias, las notificaciones con entrega real y las mini aplicaciones, pero **nada de lo descrito se ha observado todavía en la consola de Firebase**: no se comprobó que los eventos y los informes llegaran.

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
| `auth_preferences_updated` | El cliente cambió sus intereses o su segmento en «Personalización» | Ninguno: qué segmento o qué intereses no se informa |
| `auth_preferences_update_failed` | El cambio no pudo guardarse | Clase de fallo |

- **Trazas y eventos de cuentas y movimientos** ([ADR 0012](../adr/0012-lectura-de-cuentas-y-movimientos.md)), sin importes, números de cuenta, descripciones ni nombres:

| Nombre | Tipo | Cuándo se emite | Datos |
|---|---|---|---|
| `accounts_first_load` | Traza | Desde que la sesión empieza a seguir las cuentas hasta que hay algo que mostrar | Origen (`server` o `cache`) y cantidad de cuentas; o resultado `failed` si terminó sin datos |
| `movements_first_load` | Traza | Desde que se abre una cuenta hasta que hay movimientos que mostrar | Igual que la anterior |
| `accounts_data_load_failed` | Evento | Una actualización no pudo completarse, o la escucha en tiempo real terminó con un error | Servicio (`accounts` o `movements`) y clase de fallo (`offline`, `timeout`, `unavailable`, `unexpected`; una escucha rota es `unexpected`) |
| `accounts_data_retry_requested` | Evento | El cliente toca «Reintentar» | Servicio |
| `accounts_data_served_from_cache` | Evento | Un conjunto de datos se mostró desde la copia del dispositivo, una vez por escucha | Servicio y cantidad de elementos |
| `accounts_data_documents_skipped` | Evento | Una entrega trajo documentos que la aplicación no pudo leer y dejó fuera; se emite cuando esa cantidad cambia | Servicio y cantidad de documentos, nunca cuáles |
| `saved_customer_data_clear_failed` | Evento y error | Al terminar la sesión, un paso de la limpieza del dispositivo falló | Paso (`database` o `sync_times`); el error viaja solo con su tipo |

Un valor distinto de cero en `accounts_data_documents_skipped` significa que algún cliente ve menos de lo que tiene, y en el caso de las cuentas que no ve su saldo total: merece una alerta. `saved_customer_data_clear_failed` indica datos de un cliente que quedaron en un dispositivo después de cerrar sesión; la limpieza se repite al abrir la aplicación sin sesión.

- **Errores inesperados de cuentas y movimientos**, con el motivo `accounts_unexpected` y solo el tipo del error.
- **Eventos de la política de resiliencia** (`resilience_timeout`, `resilience_retry`, `resilience_attempts_exhausted`) para los servicios `auth`, `profile`, `accounts` y `movements`, que ya la usan.
- **Errores inesperados del proveedor de identidad**, con el motivo `auth_unexpected` y solo el tipo del error, porque su mensaje puede citar el correo.

- **Eventos del inicio** ([ADR 0013](../adr/0013-registro-de-modulos-y-motor-del-inicio.md)), con tipos de módulo y cantidades, nunca datos del cliente:

| Nombre | Cuándo se emite | Datos |
|---|---|---|
| `home_module_skipped` | La configuración publica como visible un tipo de módulo que esta versión no registra. Una vez por tipo y sesión | Tipo del módulo |
| `home_refresh_requested` | El cliente desliza para actualizar el inicio, o reintenta desde el error de pantalla completa | Cantidad de módulos que se actualizan |
| `home_nothing_to_show` | Todo lo que el inicio dibujaría es un módulo con datos que falló. Se emite al entrar en ese estado, y de nuevo solo después de haberse recuperado | Ninguno |

- **Eventos de notificaciones** ([ADR 0018](../adr/0018-notificaciones-y-bandeja.md)). Ninguno lleva título, texto, dirección del dispositivo ni identificador del cliente.

| Nombre | Cuándo se emite | Datos |
|---|---|---|
| `notifications_primer_shown` | Se mostró la invitación a activar notificaciones | Ninguno |
| `notifications_primer_accepted` | El cliente aceptó la invitación | Ninguno |
| `notifications_primer_declined` | El cliente eligió «Ahora no» | Ninguno |
| `notifications_permission_result` | Respuesta al aviso del sistema | `result`: granted, denied, notAsked |
| `notifications_device_registered` | El dispositivo quedó registrado para el cliente | Ninguno |
| `notifications_device_failed` | Falló un paso del registro, del olvido del dispositivo o de la limpieza tras una sesión terminada o un cambio de cliente | `step`: register, subscribe, unsubscribe, remove, delete_token |
| `notification_opened` | El cliente abrió una notificación | `kind`, `source`: inbox, system |
| `notifications_load_failed` | La bandeja no pudo actualizarse | `reason`: offline, timeout, unavailable, unexpected |

Un valor sostenido de `notifications_device_failed` con `step: delete_token` indica dispositivos que conservan una dirección que debía eliminarse. En el servidor, `transfer_notice_failed` deja una línea con el paso (`inbox` o `push`) cuando no se pudo avisar de una transferencia realizada; el aviso nunca retrasa ni cambia la respuesta de la transferencia.

- **Eventos de las mini aplicaciones de aliados** ([ADR 0019](../adr/0019-mini-aplicaciones-de-aliados.md)). Ninguno lleva lo que el cliente escribió en la página del aliado ni lo que esta respondió.

| Nombre | Cuándo se emite | Datos |
|---|---|---|
| `mini_app_opened` | El cliente abrió una mini aplicación; una vez, aunque reintente | `service` |
| `mini_app_loaded` | La página del aliado terminó de cargar | `service`, `duration` (`under_1s`, `1_to_3s`, `3_to_8s`, `over_8s`) |
| `mini_app_unavailable` | La mini aplicación no pudo mostrarse; una vez por carga, aunque el fallo se informe varias veces | `service`, `reason` (`not_configured`, `offline`, `outage`, `timeout`, `http_error`, `load_failed`) |
| `mini_app_navigation_blocked` | La página, o un marco suyo, intentó salir del origen del aliado | `service`, `origin` (solo esquema, host y puerto) |
| `mini_app_completed` | La página informó que el cliente terminó; una vez por carga | `service` |
| `mini_app_message_dropped` | Llegó un mensaje fuera del contrato, durante la carga o con la vista web fuera del origen del aliado | `service` |

`load_failed` incluye el caso de un borrado pendiente que no pudo completarse antes de cargar. `saved_customer_data_clear_failed` con `step` = `mini_app_data` indica que no se pudo borrar lo que guardó la vista web al cerrar sesión. Los eventos de notificaciones y de mini aplicaciones los emite la aplicación y están cubiertos por pruebas; ninguno se ha visto llegar a la consola de Firebase.

- **Señales de la configuración.** Desde la etapa 6 la aplicación escucha la configuración publicada mientras hay una sesión iniciada, así que emite las señales de la tabla siguiente. Los movimientos más recientes del inicio usan los mismos eventos y el mismo servicio (`movements`) que los del detalle de una cuenta.

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

Al cerrar sesión, la escucha de la configuración se cancela. Como la sesión termina un instante antes, el servidor puede denegar la escucha y la aplicación emitir un `config_source_failed` de más; es un falso positivo conocido de ese momento.

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
| Fallos agrupados por `config_version` | Un fallo causado por una configuración publicada, no por el código | Clave personalizada | La aplicación lo emite desde la etapa 6 |
| Eventos `config_rejected` | La consola publicó un documento que las aplicaciones instaladas no entienden | Evento de Analytics | La aplicación lo emite desde la etapa 6 |
| Eventos y errores `config_source_failed` | La aplicación no puede leer la configuración (permisos, red). El número de fallo distingue un corte puntual de uno sostenido | Analytics y Crashlytics | La aplicación lo emite desde la etapa 6 |
| Eventos `config_applied` con origen `lastResort` o `bundled` en usuarios que no son nuevos | Dispositivos que no reciben la configuración publicada | Evento de Analytics | La aplicación lo emite desde la etapa 6 |
| Cualquier evento `resilience_fault_injection_enabled` | Una compilación de demostración llegó a usuarios reales | Evento de Analytics | La aplicación lo emite desde la etapa 6 |

El caso que más interesa en esta arquitectura es el cuarto. La experiencia cambia sin publicar la aplicación, así que un fallo puede empezar sin que haya una versión nueva a la que atribuirlo. Con la versión de configuración en cada informe, la pregunta «¿qué cambió?» tiene respuesta: se compara la versión de configuración de los informes anteriores y posteriores al inicio del problema, y la consola permite volver a publicar la anterior.

## Detección de problemas de experiencia

Un fallo es visible. Una pantalla que tarda, un reintento constante o un módulo que no carga no lo son, salvo que se midan.

| Señal | Qué indica | Fuente | Estado |
|---|---|---|---|
| Duración de `home_load` | Cuánto tarda el inicio en ser útil, por origen de datos (red o caché) | Traza de Performance | No construida. Hoy lo aproximan `accounts_first_load` y los eventos de carga de movimientos |
| Duración de `transfer_settle` | Latencia de la operación más sensible: cuánto tarda el servidor en liquidar una orden | Traza de Performance | La aplicación la emite |
| Proporción de `transfer_not_sent` frente a `transfer_confirmed`, por clase de fallo | Órdenes que quedan sin respuesta: el peor estado para el cliente | Evento de Analytics | La aplicación los emite |
| `transfer_queued` y `transfer_queued_settled` por resultado | Cuánto se transfiere sin conexión y cómo termina | Evento de Analytics | La aplicación los emite |
| `transfer_stopped` por motivo (`sessionExpired`, `orderChanged`, `notAccepted`) | Sesiones caducadas a mitad de una operación, o un cliente y un servidor que no se entienden | Evento de Analytics | La aplicación lo emite |
| Error `transfer_queue_write_refused` | El banco no aceptó una orden que estaba en cola | Crashlytics, error no fatal | La aplicación lo emite |
| `transfer_rejected` por motivo | Qué reglas del servidor frenan a los clientes | Evento de Analytics | La aplicación lo emite |
| `accounts_provision_failed` por clase de fallo | Clientes nuevos que se quedan sin cuentas | Evento de Analytics | La aplicación lo emite |

Los eventos de transferencias llevan el motivo o la clase de fallo, nunca el importe, las cuentas, el concepto ni el identificador de la orden.

| Eventos `resilience_timeout`, `resilience_retry` y `resilience_attempts_exhausted`, por servicio | El servicio responde mal aunque no haya fallos | Evento de Analytics | La aplicación los emite para acceso, cuentas y movimientos |
| Duración de `accounts_first_load` y `movements_first_load`, por origen | Cuánto tarda el cliente en ver su saldo y sus movimientos, y cuántas veces los ve desde la copia | Traza de Performance | La aplicación las emite |
| Proporción de `accounts_data_load_failed` por servicio y clase de fallo | Indisponibilidad parcial: los movimientos fallan mientras las cuentas responden, o al revés | Evento de Analytics | La aplicación emite el evento |
| Proporción de `accounts_data_served_from_cache` | Cuánto se usa la aplicación con datos guardados | Evento de Analytics | La aplicación emite el evento |
| Eventos `accounts_data_retry_requested` | Clientes que insisten ante un error: mide la fricción que deja una falla | Evento de Analytics | La aplicación emite el evento |
| Eventos `home_nothing_to_show` | Clientes que abrieron el inicio y no vieron nada: la peor experiencia posible del inicio | Evento de Analytics | La aplicación emite el evento |
| Eventos `home_module_skipped`, por tipo | Cuántas aplicaciones instaladas no conocen un módulo ya publicado: mide cuándo conviene publicarlo | Evento de Analytics | La aplicación emite el evento |
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
