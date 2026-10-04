# 0018. Notificaciones push y bandeja del cliente

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** construida en la etapa 9. Paquete `packages/feature_notifications`, cableado en `apps/mobile` (`notifications_wiring.dart`, `notifications_composition.dart`), reglas de `users/{uid}/devices` y `users/{uid}/inbox` en `firebase/firestore.rules`, y escritura de la bandeja al enviar en `apps/backoffice/lib/server/push.ts`. Verificada con pruebas, con el emulador de reglas y compilando el APK. **No verificada en un dispositivo ni contra el servicio real de mensajería**: ver «Qué no está verificado».

## Problema a resolver

El enunciado pide notificaciones push para clientes. Una notificación push, por sí sola, es un aviso que el sistema operativo puede no entregar: el cliente puede no haber dado permiso, tener el teléfono apagado o haber descartado el aviso sin leerlo. Si la notificación solo existe como push, lo que el banco le dijo al cliente se pierde.

Hay que decidir cinco cosas:

1. Dónde vive la notificación para que el cliente la encuentre después.
2. A quién se dirige un envío: a un segmento o a una persona.
3. Cuándo se pide el permiso del sistema, que solo se puede pedir una vez.
4. Qué pasa con el dispositivo cuando el cliente cierra sesión.
5. Qué ocurre al tocar una notificación.

## Alternativas evaluadas

**Dónde vive la notificación**

1. **Solo push.** Lo más simple. No hay historial, y quien no dio permiso no recibe nada.
2. **El teléfono guarda lo que recibe.** Hay historial, pero solo de lo que llegó a ese teléfono mientras tenía permiso, y se pierde al cerrar sesión, donde la aplicación borra todo lo guardado del cliente.
3. **El servidor escribe una bandeja por cliente y el push solo la anuncia.** La bandeja es la fuente de verdad: está aunque el push no llegue, es la misma en todos los dispositivos del cliente y se lee con las mismas garantías que las cuentas.

**A quién se dirige**

- **Solo temas por segmento.** No requiere guardar direcciones, pero no permite escribirle a una persona.
- **Solo direcciones por dispositivo.** Permite todo, pero un envío a un segmento obliga a leer todas las direcciones.
- **Tema por segmento y direcciones por cliente.** Cada caso usa lo que le conviene.

**Cuándo pedir permiso**

- **Al abrir la aplicación.** Es lo habitual y lo que más rechazos produce: el cliente aún no sabe para qué son.
- **Con una invitación propia antes del aviso del sistema, en contexto.** El aviso del sistema solo aparece si el cliente acepta la invitación; un «Ahora no» no lo gasta.

## Opción seleccionada

**Bandeja escrita por el servidor, con FCM como aviso.** Al enviar, la consola escribe un documento por destinatario en `users/{uid}/inbox/{id}` con título, texto, tipo, destino, fecha y `read: false`, y además manda el push. El identificador es el del registro del envío, de modo que un reintento escribe el mismo documento y no duplica.

```mermaid
sequenceDiagram
  participant C as Consola
  participant F as Firestore
  participant M as FCM
  participant A as Aplicación
  C->>M: push al tema del segmento o a las direcciones del cliente
  C->>F: un documento por destinatario en users/{uid}/inbox
  F-->>A: la escucha de la bandeja entrega el documento
  M-->>A: aviso del sistema (si hay permiso)
  A->>F: al tocarla, read pasa de false a true
```

- **Reglas.** El cliente lee su bandeja y solo puede cambiar `read` de `false` a `true`. No crea, no borra y no cambia ningún otro campo: una notificación del banco no la puede escribir ni alterar un cliente.
- **Envío a un segmento.** El push va al tema `segment-<id>`. La bandeja se escribe para los clientes del segmento en un solo lote de la base de datos, hasta 500. Si el segmento es mayor, el registro del envío lo dice (`inboxTruncated`).
- **Envío a una persona.** El push va a las direcciones guardadas en `users/{uid}/devices`, y la bandeja a ese cliente.
- **Ensayos.** Un envío en modo de prueba no escribe bandejas: no se anunció nada.
- **Tipo.** La consola no tiene un campo para el tipo; se deduce del destino (cuentas o transferencia: movimiento; perfil: seguridad; el resto: beneficio).

**Registro del dispositivo.** Con permiso concedido y sesión iniciada, la aplicación guarda `users/{uid}/devices/{deviceId}` con `token`, `platform` y `updatedAt`, y se suscribe al tema de su segmento. Si el cliente cambia de segmento, deja el tema anterior y sigue el nuevo. Si el servicio rota la dirección, la aplicación reemplaza el documento entero, con lo que desaparece la marca `unregistered` que la consola hubiera puesto sobre la dirección anterior. Las reglas permiten al dueño crear, reemplazar y borrar sus dispositivos, con tres campos exactos, dirección acotada y hora del servidor.

**Invitación antes del permiso.** La primera vez que un cliente inicia sesión en un dispositivo donde el sistema aún no preguntó, la aplicación muestra su invitación sobre el inicio. Solo si acepta aparece el aviso del sistema. «Ahora no» se recuerda en el dispositivo y la aplicación no vuelve a invitar por su cuenta; la bandeja ofrece activarlas cuando el cliente quiera. Si el permiso está denegado en el sistema, la bandeja lo dice y lleva a los ajustes.

**Cierre de sesión.** Antes de cerrar la sesión, la aplicación deja el tema, borra el documento del dispositivo y elimina la dirección local. El orden importa: borrar el documento exige una sesión. La espera está acotada a 5 segundos: un cliente no queda con la sesión abierta porque la red no responde. Después corre la limpieza ya existente (escucha de configuración detenida, base local borrada).

**Al tocar una notificación.** El destino se resuelve con el mismo resolvedor que usan las acciones del inicio. Un destino que esta versión no puede abrir lleva a la bandeja. Con la aplicación abierta el sistema no muestra nada, así que la aplicación muestra un aviso propio; la bandeja se actualiza por su escucha.

## Trade-offs

- **Se gana:** el cliente encuentra lo que el banco le dijo aunque el push no haya llegado; la bandeja falla y se recupera por separado de cuentas y movimientos (servicio `notifications` en la política de resiliencia); sin conexión muestra lo guardado; al cerrar sesión el dispositivo deja de recibir lo del cliente.
- **Se paga, un envío a un segmento escribe un documento por cliente.** Con 500 por envío alcanza para la demostración. En producción la escritura se haría desde una cola, o los avisos de segmento vivirían en una colección compartida que la aplicación combina con la bandeja personal.
- **Se paga, el push y la bandeja no son una sola operación.** Si el push sale y la bandeja falla, el envío queda como enviado y el registro anota el error (`inboxError`). No hay reintento automático de la bandeja.
- **Se paga, la entrega del push no está garantizada.** FCM entrega «en lo posible». El servidor no sabe si un push a un tema llegó a alguien. Por eso la bandeja es la fuente de verdad y no al revés.
- **Se paga, tocar el aviso del sistema no marca la notificación como leída.** El push no lleva el identificador de la bandeja; se marca al tocarla en la bandeja.
- **Se paga, el tipo se deduce del destino.** Un beneficio que lleve a las cuentas se dibuja como movimiento. Un campo de tipo en la consola lo resolvería.
- **Límite conocido, cierre de sesión por otra vía.** El dispositivo se olvida cuando el cliente pulsa «Cerrar sesión». Una sesión que termina de otro modo (revocada o caducada) no pasa por ahí: la dirección queda registrada hasta que la consola la marque o el cliente vuelva a entrar. La bandeja sigue protegida por las reglas; lo que podría llegar es el texto de un push.
- **Límite conocido, Android no distingue «aún no preguntado» de «denegado».** La aplicación recuerda en el dispositivo si ya mostró el aviso del sistema. Si esa memoria se borra, un permiso denegado se toma por no preguntado y la invitación vuelve a aparecer una vez.
- **Límite conocido, abrir los ajustes del sistema está implementado solo en Android**, por un canal propio en `MainActivity`. En iOS la llamada se informa a telemetría y no hace nada.

### Qué no está verificado

Nada de esto corrió en un teléfono ni contra FCM. En particular: la recepción real de un push, el aviso de permiso de Android 13, el registro de la dirección y del tema, la apertura desde un aviso con la aplicación cerrada, el canal de notificaciones de Android y todo lo de iOS (capacidad de notificaciones, APNs y `UIBackgroundModes`, añadido pero sin compilar). Las reglas nuevas tienen pruebas contra el emulador y no están desplegadas. Queda una verificación en dispositivo pendiente para la integración.

## Impacto a largo plazo

- La bandeja admite cualquier emisor futuro (transferencias, seguridad, campañas) sin tocar la aplicación: basta con que el servidor escriba el documento con un destino de la lista del contrato.
- Los destinos de las notificaciones y los del inicio comparten resolvedor. Un destino nuevo se habilita una vez y sirve para ambos.
- Si el volumen crece, la escritura por destinatario es lo primero que hay que mover a un proceso en segundo plano; el contrato del documento no cambia.
- La decisión de pedir permiso con invitación propia es independiente del proveedor: cambiar FCM por otro servicio solo toca el adaptador.
