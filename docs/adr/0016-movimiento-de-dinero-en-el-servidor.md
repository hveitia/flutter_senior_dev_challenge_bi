# 0016. Movimiento de dinero en el servidor: solicitud pendiente, idempotencia y una sola transacción

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existen en `apps/backoffice` las rutas `POST /api/transfers`, `POST /api/transfers/{transferId}/process` y `POST /api/accounts/provision`, con la autenticación de clientes por token, la decisión de la transferencia como función pura y su liquidación en una transacción. Se comprobó en local contra el proyecto real con el cliente de prueba: una transferencia y su reverso, la repetición de la misma solicitud, dos envíos simultáneos y un sobregiro. La aplicación ya llama a estas rutas ([ADR 0017](0017-transferencias-en-la-aplicacion.md)) y la regla de Firestore que le permite crear la solicitud pendiente está en `firebase/firestore.rules`, con sus pruebas, y desplegada. El servidor está desplegado en Firebase App Hosting y ahí se repitió la comprobación con un token real de cliente. En un teléfono se vieron de punta a punta el flujo en línea y el camino en cola: una orden hecha en modo avión, conservada tras reiniciar la aplicación y liquidada sola al reconectar.

## Problema a resolver

La aplicación debe transferir dinero entre las cuentas de un mismo cliente. Tres condiciones lo complican:

- **Un cliente nunca escribe saldos.** Las reglas de Firestore niegan a la aplicación cualquier escritura en cuentas y movimientos ([ADR 0002](0002-firebase-como-backend.md), [ADR 0012](0012-lectura-de-cuentas-y-movimientos.md)). Alguien con privilegios tiene que hacerlo en su nombre.
- **La red de un teléfono falla a mitad de camino.** Una petición puede llegar, ejecutarse y perder la respuesta. La aplicación no sabe si el dinero se movió, y lo razonable es que vuelva a enviarla. La política de resiliencia ([ADR 0009](0009-politica-de-resiliencia.md)) solo reintenta lo que se declara repetible.
- **La transferencia debe poder ordenarse sin conexión.** El enunciado pide demostrar el comportamiento con conectividad limitada; la orden tiene que sobrevivir en el teléfono y ejecutarse al volver la red.

El riesgo concreto es el doble débito: que un reintento, una cola que se vacía dos veces o dos pestañas ejecuten dos veces la misma orden.

## Alternativas evaluadas

**Quién ejecuta la transferencia**

1. **Una ruta del servidor Next.js, con privilegios de administrador.** El servidor ya existe para la consola ([ADR 0004](0004-backoffice-y-api-en-nextjs.md)); no añade infraestructura.
2. **Una Cloud Function disparada al crearse la solicitud.** Es el encaje más natural para una cola: la aplicación escribe la solicitud y no llama a nadie. Exige el plan de pago del proyecto.
3. **Una transacción desde la aplicación, vigilada por las reglas.** Sin servidor. Obliga a que las reglas demuestren que la suma de dos cuentas no cambia, y deja la decisión en un dispositivo que el banco no controla.
4. **Un núcleo bancario externo.** Es lo que habría en producción; queda fuera del alcance del reto.

**Cómo se evita ejecutar dos veces**

1. **La solicitud es un documento con un identificador que elige la aplicación, y ese identificador es la clave de idempotencia.** El mismo documento sirve de cola sin conexión y de registro del resultado.
2. **Una cabecera `Idempotency-Key` y una tabla de claves en el servidor.** Es el patrón habitual de las API de pagos; no resuelve la cola sin conexión, que necesitaría otro mecanismo.
3. **Ninguna clave, y no reintentar nunca.** Tras una respuesta perdida, el cliente no sabría si su dinero se movió.

**Cómo se mantienen coherentes saldos, movimientos y resultado**

1. **Una sola transacción de Firestore** que lee la solicitud y las dos cuentas y escribe todo junto.
2. **Varias escrituras seguidas, con compensación si una falla.** Deja ventanas en las que el saldo y el historial no coinciden.

## Opción seleccionada

La primera opción en los tres casos.

**La solicitud.** Cada transferencia es un documento `users/{uid}/transfers/{transferId}`. El identificador lo genera la aplicación (un UUID) antes de enviar nada, y no cambia entre reintentos.

| Estado | Quién lo escribe | Significado |
|---|---|---|
| `pending` | La aplicación (en cola) o el servidor (en línea) | Orden registrada, sin ejecutar. No retiene fondos |
| `completed` | Solo el servidor | Saldos y movimientos escritos; lleva `reference` y `processedAt` |
| `rejected` | Solo el servidor | No se ejecutó; lleva `reason` y `processedAt` |

**Dos caminos, una sola función** (`lib/server/transfers.ts`):

- **En línea:** `POST /api/transfers` recibe la orden con su `transferId`. Si la solicitud no existe, se crea y se liquida en la misma transacción.
- **En cola:** la aplicación escribe la solicitud pendiente en Firestore, donde la persistencia local la conserva sin red, y al reconectar llama a `POST /api/transfers/{transferId}/process`, sin cuerpo.

**Una transacción.** La liquidación lee la solicitud, lee las dos cuentas, decide, y escribe los dos saldos, los dos movimientos (con una referencia compartida) y el resultado. O se escribe todo o no se escribe nada. Si otra transacción modifica algo de lo leído, la base de datos vuelve a ejecutar la función con el estado nuevo.

**Idempotencia.** Una solicitud ya liquidada devuelve lo que se registró y no escribe nada, se llame las veces que se llame y aunque los saldos hayan cambiado. Tres barreras lo sostienen:

1. La transacción comprueba el estado antes de mover nada.
2. Dos llamadas simultáneas no pueden encontrar ambas la solicitud pendiente: la segunda se ejecuta contra lo que dejó la primera.
3. Los movimientos tienen identificadores derivados de la transferencia (`{transferId}-out`, `{transferId}-in`): escribirlos dos veces escribe los mismos dos documentos.

El mismo identificador con una orden distinta se rechaza (`409`), en lugar de responder con el resultado de otra orden.

**La decisión** (`lib/api/transfer.ts`) es una función pura sobre la orden y las dos cuentas. Importes en centavos enteros; nunca decimales. Motivos de rechazo, como códigos estables: `invalid-amount`, `same-account`, `unknown-account`, `currency-mismatch`, `insufficient-funds` e `invalid-request` para un documento que no es una orden.

**Límites, como constantes con nombre:** 5 000,00 USD por transferencia, 80 caracteres de concepto, 2 048 bytes de cuerpo.

**Quién es el cliente.** Cada ruta exige `Authorization: Bearer <token de identidad>`, verificado con comprobación de revocación. El identificador del cliente sale solo del token: no hay ningún campo del cuerpo ni de la ruta que lo indique, y un campo desconocido en el cuerpo es un error. Las rutas no leen cookies: la sesión de un administrador de la consola no abre nada aquí, y un token de cliente no abre nada en la consola ([ADR 0015](0015-acceso-de-administradores.md)).

**Alta de cuentas.** `POST /api/accounts/provision` abre las dos cuentas iniciales de un cliente que no tiene ninguna, con su depósito de apertura como movimiento. Un cliente que ya tiene cuentas las recibe tal como están. El registro en la aplicación crea solo el perfil ([ADR 0011](0011-autenticacion-y-perfil.md)); esta ruta cierra ese hueco.

**El depósito de apertura es dinero de demostración.** No tiene valor real: existe para que quien evalúe el reto pueda registrarse y transferir sin que nadie le cargue datos. El registro es abierto y el correo no se verifica, de modo que cada cuenta nueva crea 75 dólares de saldo ficticio y nada impide crear muchas. Se deja así a propósito: exigir correo verificado dejaría a la aplicación, que no tiene ese flujo, sin poder dar de alta a nadie. Con dinero real, el alta no acreditaría nada y exigiría identidad verificada.

**Qué cuentas pueden transferir.** Solo las de ahorros y la corriente. Una cuenta de inversión no es origen ni destino: la decisión la rechaza con `account-not-eligible`.

**Qué queda de un documento escrito por un teléfono.** Al liquidar, el documento se reescribe entero con la orden que el servidor leyó, su fecha de creación y el resultado. No se fusiona con lo almacenado: una referencia, un motivo o una fecha de liquidación que un cliente hubiera puesto en la solicitud pendiente no sobreviven. La regla de Firestore ya impide crear un documento con esos campos; el servidor no depende de ella.

**Emuladores.** El servidor se niega a arrancar en producción si están definidas las variables de emulador de Firebase, porque con ellas aceptaría tokens sin firma.

**Qué se registra.** Una línea por petición: ruta, estado, un código de resultado, duración e identificador de petición, que también viaja en la respuesta. Ningún cliente, cuenta, importe ni mensaje de error llega al registro.

**Una solicitud que nunca se procesa.** Se queda en `pending` y no afecta a ningún saldo. La aplicación es la única que la procesa: al reconectar, o al abrirse con solicitudes pendientes. Si el teléfono no vuelve a conectarse, la transferencia no ocurre. No hay un proceso del servidor que barra las pendientes ni una fecha de caducidad.

## Trade-offs

- **Se gana:** un reintento nunca mueve dinero dos veces, así que la aplicación puede declarar la llamada como repetible y reintentarla.
- **Se gana:** una sola pieza resuelve la cola sin conexión, la idempotencia y el registro de lo ocurrido.
- **Se gana:** el cliente ve el resultado por dos vías: la respuesta de la llamada y el propio documento, que puede escuchar.
- **Se gana:** la decisión se prueba sin base de datos, con casos calculados a mano.
- **Se paga:** la cola depende de que la aplicación llame a `process`. Con una función disparada por la escritura, bastaría con que la solicitud llegara al servidor.
- **Se paga:** cada transferencia cuesta tres lecturas y cinco escrituras dentro de una transacción, y una verificación del token con consulta de revocación.
- **Se paga:** el servidor debe leer con desconfianza un documento que escribió un teléfono, aunque las reglas ya lo hayan validado.
- **Límite:** una cuenta con un saldo que no sea un entero de centavos detiene la transferencia con un error genérico, y la solicitud queda pendiente. Es deliberado: no se debita una cuenta que no se puede leer con certeza.
- **Límite:** el número de cuenta que genera el alta es aleatorio y no se comprueba que sea único entre clientes.
- **Límite:** no hay límite diario por cliente ni límite de frecuencia; solo el máximo por transferencia.
- **Límite:** solo entre cuentas propias. No hay terceros, ni otros bancos, ni retención de fondos.
- **Límite:** el alta de cuentas es un grifo de saldo ficticio para quien se registre muchas veces. Es aceptable solo porque el dinero es de demostración.
- **Sin verificar:** dos teléfonos del mismo cliente procesando la misma solicitud en cola a la vez. La simultaneidad se comprobó con dos llamadas directas a la API, no desde dos dispositivos.

## Impacto a largo plazo

- **El contrato sobrevive a un cambio de motor.** La aplicación solo conoce el identificador, los estados y los códigos. Sustituir la ruta por una función disparada, o por un núcleo bancario, no la cambia.
- **Lo que haría producción antes de mover dinero real:**
  - **Identidad verificada** antes de abrir una cuenta: correo o teléfono confirmados y validación del documento, y un alta que no acredite saldo.
  - **App Check**, para que solo la aplicación legítima llame a las rutas.
  - **Límites por cliente** (diario, por número de operaciones) y límite de frecuencia por dirección y por cuenta.
  - **Conciliación periódica:** comprobar que los movimientos de cada cuenta suman su saldo y que toda transferencia completada tiene sus dos movimientos, con alerta si no.
  - **Barrido de pendientes:** un proceso que liquide o caduque las solicitudes que la aplicación no llegó a procesar.
  - **Libro contable de partida doble** en lugar de saldos actualizados en el propio documento de la cuenta.
  - **Numeración de cuentas** asignada por el sistema del banco, con unicidad garantizada.
- **Convendría revisar la decisión** si el proyecto pasa al plan de pago: la función disparada por la escritura elimina la dependencia de que la aplicación llame a `process`, y la ruta en línea podría quedar como camino rápido.
