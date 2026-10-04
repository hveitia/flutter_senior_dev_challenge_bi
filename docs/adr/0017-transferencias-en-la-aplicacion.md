# 0017. Transferencias en la aplicación: cliente de API, cola sin conexión y prueba de extremo a extremo

- **Estado:** Aceptada
- **Fecha:** 2026-10-04
- **Implementación:** existen en `packages/feature_accounts` el dominio de la transferencia, el repositorio sobre la API de clientes, la cola de solicitudes pendientes en Firestore, el procesador de salida, el alta de cuentas y las pantallas de formulario, confirmación y resultado. `apps/mobile` los compone por cliente, habilita el destino `transfer` detrás de la funcionalidad `transfers` y avisa antes de cerrar sesión con órdenes sin enviar. La regla de Firestore que permite a la aplicación dejar la solicitud pendiente está desplegada. Lo comprobado en un dispositivo y lo que queda sin comprobar está en [conectividad degradada](../operacion/conectividad-degradada.md) y en el [registro de uso de IA](../ia/registro-uso-ia.md).

## Problema a resolver

El servidor ya mueve el dinero ([ADR 0016](0016-movimiento-de-dinero-en-el-servidor.md)). Falta el lado de la aplicación, con cuatro exigencias que tiran en direcciones distintas:

- **Nunca dos veces.** Una red móvil pierde respuestas. La aplicación tiene que poder repetir una orden sin riesgo de mover el dinero dos veces, y el cliente tiene que poder tocar «Confirmar» dos veces sin consecuencias.
- **También sin conexión.** El enunciado pide demostrar el comportamiento con conectividad limitada. Una orden hecha sin red debe sobrevivir en el teléfono, enviarse sola al volver la red y contarle al cliente cómo terminó.
- **Sin mentir sobre lo que se sabe.** «Sin conexión», «el servidor no contestó a tiempo» y «el servidor la rechazó» son tres situaciones distintas, y solo en la primera es seguro dejar la orden en cola.
- **Nada del cliente queda en el dispositivo al cerrar sesión** ([ADR 0012](0012-lectura-de-cuentas-y-movimientos.md)). Una orden en cola es un dato del cliente guardado en el dispositivo.

Además, un cliente recién registrado no tiene cuentas: solo el servidor puede abrirlas.

## Alternativas evaluadas

1. **Escribir siempre la solicitud pendiente y esperar a que el servidor la liquide.** Un solo camino, con o sin red. Se descartó como camino principal porque sin funciones disparadas por la escritura (plan de pago) nadie liquida la solicitud si la aplicación no llama, y con red el cliente esperaría dos pasos para ver un resultado que una sola llamada da.
2. **Cola propia en el almacenamiento del dispositivo** (preferencias o base local) y reenvío con la llamada en línea. Se descartó: habría que escribir persistencia, orden y limpieza al cerrar sesión para algo que la cola de escrituras de Firestore ya hace, y la orden no sería visible para el servidor hasta el reenvío.
3. **Reintentar la llamada en línea hasta que haya red, sin cola.** Se descartó: la orden se perdería al cerrar la aplicación.
4. **Encolar también tras un tiempo agotado.** Se descartó: el servidor pudo haber liquidado la orden. Escribir encima una solicitud pendiente con el mismo identificador sería rechazado por las reglas, y presentarla como «en cola» ocultaría que no se sabe qué pasó.
5. **Llamada en línea con identificador de idempotencia y cola solo cuando se sabe que no hay conexión, sobre la solicitud pendiente de Firestore.** Es la opción elegida.

## Opción seleccionada

**Una orden, un identificador.** La aplicación genera el identificador al confirmar (32 caracteres aleatorios) y lo conserva para todos los intentos de esa orden. El servidor liquida cada identificador una sola vez, de modo que la llamada se declara repetible ante la política de resiliencia ([ADR 0009](0009-politica-de-resiliencia.md)) y un reintento, automático o del cliente, nunca crea una segunda transferencia.

**Tres resultados, tres tratamientos** (`DefaultTransfersRepository`):

| Situación | Qué hace la aplicación | Qué ve el cliente |
|---|---|---|
| El dispositivo está sin conexión, o la política lo detecta antes de enviar | Escribe la solicitud pendiente `users/{uid}/transfers/{id}`; no llama al servidor | «Transferencia pendiente», etiqueta «En cola», sin «Ver movimiento» |
| El servidor responde | Muestra lo que respondió: completada con su referencia, o rechazada con su motivo | «Transferencia realizada» o el motivo del rechazo |
| El servidor no contesta a tiempo o falla, tras los reintentos | No encola: no se sabe si se liquidó | «No pudimos enviar la transferencia» y «Reintentar», que repite la misma orden |
| Un intento ya salió y, antes del siguiente, el dispositivo se queda sin conexión | No encola: la petición pudo llegar. La orden queda como «sin resolver» | Lo mismo que la fila anterior |
| El servidor responde sobre la propia petición | No reintenta: daría la misma respuesta | Ver «Respuestas que el cliente puede atender» |

**Una orden que pudo salir nunca entra en la cola.** El repositorio anota que una petición salió desde el primer intento. Si después la política informa de que no hay conexión, el resultado es «no se pudo enviar», no «en cola»: encolarla prometería un envío futuro de una orden que quizá ya está liquidada. La revisión encontró que la primera versión sí la encolaba.

**La orden sin resolver bloquea una orden nueva.** Mientras una orden salió y no tiene respuesta final, el repositorio la conserva en memoria durante la sesión, y la pantalla de transferencia se abre sobre ella, con «Reintentar», en lugar de mostrar un formulario vacío. Lo único seguro que se puede enviar es esa misma orden, con su mismo identificador. Se descartó guardarla en disco: es un importe y dos cuentas, y nada del cliente queda en el dispositivo fuera de la sesión.

**Sin salida mientras se envía.** Con la petición en vuelo, el retroceso del sistema y el botón de cerrar están desactivados.

**Respuestas que el cliente puede atender** (`HttpTransfersApi` y `DefaultTransfersRepository`):

| Respuesta | Qué hace la aplicación | Qué ve el cliente |
|---|---|---|
| `401` | Renueva el token una vez y repite la petición. Si vuelve a `401`, se detiene | «Tu sesión venció. Inicia sesión de nuevo para transferir. No se movió dinero.», sin reintento |
| `409` (el identificador se usó para otra orden) | Se detiene y descarta el identificador | Se le pide revisar sus movimientos y «Empezar de nuevo», que vuelve al formulario con un identificador nuevo |
| `400`, `413`, `415` | Se detiene | «El banco no pudo procesar esta solicitud. No se movió dinero.», sin reintento |
| `422` | Muestra el motivo del rechazo | El motivo, por ejemplo «Una de las cuentas no admite transferencias.» |
| `5xx` o sin respuesta | Reintenta la misma orden | «No pudimos enviar la transferencia» y «Reintentar» |

**Una orden en cola que el banco no acepta se cuenta.** Si la escritura pendiente es rechazada al llegar al servidor, por las reglas o porque ese identificador ya está liquidado, Firestore la retira del dispositivo. El procesador de salida pregunta entonces al servidor qué fue de ella: si se realizó, no dice nada, porque el movimiento aparece; si fue rechazada, muestra el motivo; si el servidor no sabe nada de ella, avisa de que una transferencia en cola no se pudo enviar. Antes desaparecía sin explicación.

**La cola es la escritura pendiente de Firestore.** Sin red, el documento queda en la persistencia local y Firestore lo entrega al reconectar. Las reglas permiten a la aplicación crear exactamente ese documento (seis campos, estado pendiente, hora del servidor) y nada más; solo el servidor lo liquida.

**Procesador de salida** (`TransferOutboxCubit`). Vive mientras dura la sesión. Escucha las solicitudes pendientes y, cuando hay conexión, pide al servidor que liquide cada una, de una en una y en orden. Se activa cuando cambia la cola, cuando vuelve la conexión y al iniciar la sesión. Si el servidor aún no recibió la solicitud, o no se le pudo preguntar, vuelve a intentarlo a los cinco segundos. Pedir dos veces la misma liquidación es inocuo: el servidor responde lo ya registrado.

**El resultado de una orden en cola** llega por dos vías: los movimientos aparecen en las cuentas por la misma escucha que ya usan todas las pantallas, y un rechazo se muestra como aviso en la sección de cuentas hasta que el cliente lo descarta.

**Cerrar sesión con órdenes sin enviar.** Cerrar sesión borra lo guardado en el dispositivo, y eso incluye las escrituras pendientes: esas órdenes no se enviarían nunca. La aplicación no cierra la sesión en silencio: avisa y solo continúa si el cliente lo confirma. La acción por defecto es quedarse. El aviso distingue dos casos, porque «descartar» solo es verdad para uno. Las órdenes que existen solo en el teléfono se descartan y no se enviarán. Las que el banco ya recibió no las puede retirar ningún cliente, porque las reglas no permiten borrar ni modificar una solicitud: el aviso dice que no se descartan y que se completarán cuando el cliente vuelva a iniciar sesión, que es cuando la aplicación pide su liquidación. Si solo hay órdenes de ese tipo, el botón dice «Cerrar sesión», sin «descartar».

**Validación antes de enviar.** Una función pura comprueba cuentas distintas, monto mayor que cero, máximo por transferencia y saldo disponible, con los mismos límites que el servidor y que la regla. El servidor decide de todos modos: la validación local solo evita un viaje que se sabe inútil.

**Solo dinero disponible.** El formulario ofrece las cuentas de ahorros y corriente. Una inversión no se transfiere, ni en la aplicación ni en el servidor.

**Alta de cuentas.** `AccountProvisioningCubit` sigue las cuentas del cliente: la primera vez que el servidor confirma que no tiene ninguna, pide el alta una vez. Las cuentas llegan después por la escucha habitual. Una copia vacía guardada en el dispositivo no cuenta como confirmación. Si el alta falla, el cliente puede pedirla de nuevo.

**Puntos de entrada detrás de la funcionalidad.** El destino `transfer` se resuelve solo si la configuración publicada tiene `transfers` activa para el segmento del cliente. Con ella apagada desaparecen en vivo la acción rápida, la acción del banner y el botón del detalle de cuenta.

**Cliente de API** (`HttpTransfersApi`). La dirección base llega por `--dart-define=API_BASE_URL`. Cada petición lleva el token de identidad de la sesión. Un servidor que falla o no acepta la conexión es «servicio no disponible» y se reintenta; una respuesta sobre la propia petición (sesión no aceptada, identificador reutilizado) no se reintenta y se reporta solo por su código. En desarrollo, Android permite HTTP sin cifrar únicamente hacia la máquina del desarrollador, y solo en compilaciones de depuración y de perfil. La regla también está en el código (`apps/mobile/lib/api_base_url.dart`): una compilación de publicación exige una dirección `https` y se niega a arrancar sin ella, en lugar de apuntar en silencio a `localhost` o enviar el token sin cifrar. El cliente no sigue redirecciones.

**Prueba de extremo a extremo** (`apps/mobile/integration_test/transfer_flow_test.dart`). Conduce la aplicación real en un dispositivo: inicia sesión, transfiere un dólar de la cuenta de ahorros a la corriente y lo devuelve con una segunda orden, y comprueba en cada una que el movimiento que aparece en la cuenta lleva la referencia que devolvió el servidor. Los saldos terminan como empezaron, así que puede repetirse sin límite. No usa dobles: corre contra el proyecto real y la API en local, con un cliente de prueba cuyas credenciales llegan por variables de compilación y no se guardan en el repositorio.

## Trade-offs

- **Se gana:** un toque doble, un reintento automático y un reintento del cliente son la misma orden.
- **Se gana:** la cola no añade almacenamiento propio ni código de sincronización.
- **Se gana:** la aplicación nunca presenta como «en cola» una orden que el servidor quizá ya liquidó.
- **Se paga:** la cola depende de que la aplicación esté abierta para pedir la liquidación. Con una función disparada por la escritura bastaría con que la solicitud llegara.
- **Se paga:** una orden que solo existe en el teléfono se descarta si el cliente cierra sesión antes de recuperar la conexión. Se le avisa y lo decide él.
- **Se paga:** la prueba de extremo a extremo necesita un dispositivo, la API en marcha y un cliente de prueba; no corre en la integración continua.
- **Se paga:** cada ejecución de esa prueba deja cuatro movimientos reales en el cliente de prueba, aunque los saldos no cambien.
- **Se paga:** una orden sin resolver impide empezar otra hasta que el servidor responda. Es deliberado: la alternativa es arriesgar un segundo envío.
- **Lo que no se puede garantizar:** si el sistema cierra la aplicación con una orden sin resolver, esa memoria se pierde. Al volver, el cliente ve un formulario vacío; si el servidor la liquidó, el movimiento aparece en la cuenta, pero nada le impide repetirla a mano. Cerrar ese hueco exige guardar la orden en el dispositivo o consultarla en el servidor al abrir, y no se hizo.
- **Sin verificar en un dispositivo:** la cola sin conexión, su liquidación al reconectar, su supervivencia a un reinicio, el bloqueo de salida mientras se envía y la versión de la prueba de extremo a extremo con el viaje de vuelta. El teléfono estaba bloqueado durante esta revisión. Todo ello está cubierto por pruebas automáticas.
- **Límite:** el aviso de rechazo de una orden en cola no dice de qué orden se trata cuando hay varias.
- **Límite:** el saldo que valida el formulario es el que tiene el dispositivo, que sin conexión puede estar desactualizado. El servidor decide con el saldo real.
- **Límite:** no hay comprobante para compartir ni transferencias a terceros.

## Impacto a largo plazo

- **El contrato no cambia si cambia el motor.** La aplicación conoce un identificador, tres estados y unos códigos. Pasar a una función disparada por la escritura o a un núcleo bancario no toca las pantallas ni el repositorio.
- **La cola sirve para otras órdenes.** El mismo patrón (solicitud pendiente con identificador propio, liquidación idempotente, procesador de salida) vale para pagos de servicios o recargas.
- **Lo que haría producción:** un barrido en el servidor que liquide o caduque las solicitudes pendientes sin depender de la aplicación, una prueba de extremo a extremo contra un entorno dedicado en la integración continua, y la confirmación de la orden con un segundo factor.
- **Convendría revisar la decisión** si la cola pasa a contener órdenes que no se pueden descartar al cerrar sesión: entonces la cola tendría que vivir en el servidor desde el primer momento.
