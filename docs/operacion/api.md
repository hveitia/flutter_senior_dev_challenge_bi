# API de clientes: rutas, contrato y cómo llegar a ella

Rutas del servidor que la aplicación móvil llama en nombre del cliente que tiene la sesión iniciada. Viven en el mismo servidor Next.js que la consola (`apps/backoffice`), bajo `app/api/`. Las decisiones están en el [ADR 0016](../adr/0016-movimiento-de-dinero-en-el-servidor.md); la configuración y el arranque del servidor, en [backoffice.md](backoffice.md).

Estado: construidas y probadas en local contra el proyecto real. Sin desplegar. La aplicación todavía no las llama.

## Lo común a todas las rutas

| Aspecto | Valor |
|---|---|
| Método | `POST` |
| Autenticación | `Authorization: Bearer <token de identidad de Firebase>` del cliente. Se verifica en cada llamada, con comprobación de revocación |
| Quién es el cliente | Solo lo dice el token. Ningún campo del cuerpo ni de la ruta lo indica |
| Cookies | No se leen. La sesión de un administrador no sirve aquí |
| Cuerpo | JSON, `Content-Type: application/json`, como máximo 2 048 bytes. Solo `POST /api/transfers` lleva cuerpo |
| Importes | Enteros en centavos. `15010` son 150,10 USD |
| Respuesta | JSON. Lleva `x-request-id` y `Cache-Control: no-store` |
| Errores | `{ "error": "<código>" }`, con campos adicionales según el código. El texto que ve el cliente lo pone la aplicación |

El orden de las comprobaciones es siempre el mismo: primero quién llama, después el cuerpo. Una llamada sin credenciales recibe `401` aunque su cuerpo sea inválido.

## `POST /api/accounts/provision`

Abre las cuentas iniciales del cliente si no tiene ninguna. Sin cuerpo. La aplicación la llama después del registro; repetirla no cambia nada.

Respuesta `200`:

```json
{
  "created": true,
  "accounts": [
    { "id": "savings", "name": "Cuenta de ahorros", "kind": "savings", "number": "2212345678", "availableCents": 5000, "ledgerCents": 5000, "currency": "USD" },
    { "id": "checking", "name": "Cuenta corriente", "kind": "checking", "number": "2287654321", "availableCents": 2500, "ledgerCents": 2500, "currency": "USD" }
  ]
}
```

`created` es `false` cuando el cliente ya tenía cuentas; `accounts` son entonces las que tiene, sin modificar. Los números del ejemplo son ilustrativos.

| Estado | Código | Cuándo |
|---|---|---|
| `401` | `unauthorized` | Token ausente, inválido, caducado o revocado |
| `422` | `profile-required` | El cliente no tiene documento de perfil todavía |

## `POST /api/transfers`

Transfiere entre dos cuentas del cliente. La solicitud se crea y se liquida en una sola transacción.

Cuerpo:

```json
{
  "transferId": "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f",
  "fromAccountId": "savings",
  "toAccountId": "checking",
  "amountCents": 15010,
  "concept": "Arriendo de octubre"
}
```

| Campo | Regla |
|---|---|
| `transferId` | Lo genera la aplicación antes del primer intento y lo reutiliza en cada reintento. De 16 a 64 caracteres entre letras, dígitos, `-` y `_`; un UUID sirve |
| `fromAccountId`, `toAccountId` | Identificadores de cuentas del cliente, distintos entre sí |
| `amountCents` | Entero, mayor que 0 y como máximo `500000` |
| `concept` | Opcional. Texto de una línea, hasta 80 caracteres |

No se admite ningún otro campo.

Respuesta `200`, transferencia completada:

```json
{
  "transfer": {
    "id": "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f",
    "status": "completed",
    "processedAt": "2026-10-03T14:00:00.000Z",
    "reference": "TRF-202610-3FA91C07B2"
  }
}
```

Respuesta `422`, transferencia rechazada:

```json
{
  "error": "transfer-rejected",
  "reason": "insufficient-funds",
  "transfer": {
    "id": "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f",
    "status": "rejected",
    "processedAt": "2026-10-03T14:00:00.000Z",
    "reason": "insufficient-funds"
  }
}
```

Enviar otra vez la misma orden con el mismo `transferId` devuelve exactamente la misma respuesta, sea `200` o `422`, y no mueve nada. Un rechazo es definitivo para ese identificador: para volver a intentarlo con fondos suficientes, la aplicación genera uno nuevo.

| Estado | Código | Campos adicionales | Cuándo |
|---|---|---|---|
| `400` | `invalid-json` | | El cuerpo no es un objeto JSON en UTF-8 |
| `400` | `invalid-request` | `fields`: nombres de los campos incorrectos o desconocidos | La orden no cumple las reglas de la tabla anterior |
| `401` | `unauthorized` | | Token ausente, inválido, caducado o revocado |
| `409` | `idempotency-key-reused` | | Ya existe una solicitud con ese `transferId` y una orden distinta |
| `413` | `payload-too-large` | | Cuerpo de más de 2 048 bytes |
| `415` | `unsupported-media-type` | | El cuerpo no se declara como JSON |
| `422` | `transfer-rejected` | `reason`, `transfer` | La orden es válida pero no puede ejecutarse |
| `500` | `internal` | | Error inesperado. No se movió nada |
| `503` | `unavailable` | | La base de datos no respondió. Puede repetirse la llamada con el mismo `transferId` |

Motivos de rechazo (`reason`):

| Motivo | Significado |
|---|---|
| `insufficient-funds` | El saldo disponible de la cuenta de origen no cubre el importe |
| `unknown-account` | El cliente no tiene una de las dos cuentas |
| `account-not-eligible` | Una de las cuentas no es de ahorros ni corriente (por ejemplo, una inversión) |
| `currency-mismatch` | Las cuentas están en monedas distintas |
| `same-account` | Origen y destino son la misma cuenta |
| `invalid-amount` | El importe no es un entero positivo dentro del máximo |
| `invalid-request` | El documento pendiente no es una orden legible |

Los tres últimos solo pueden darse en una solicitud en cola: en esta ruta, esos casos se rechazan antes con `400`.

## `POST /api/transfers/{transferId}/process`

Liquida una solicitud que la aplicación dejó pendiente en `users/{uid}/transfers/{transferId}`, normalmente porque se ordenó sin conexión. Sin cuerpo; si se envía, no se lee.

Responde igual que `POST /api/transfers`: `200` con la transferencia completada o `422` con el rechazo. Puede llamarse cualquier número de veces, y desde dos sitios a la vez: la primera llamada liquida y las demás reciben ese resultado.

| Estado | Código | Cuándo |
|---|---|---|
| `400` | `invalid-request`, con `fields: ["transferId"]` | El identificador de la ruta no tiene la forma de un `transferId` |
| `401` | `unauthorized` | Token ausente, inválido, caducado o revocado |
| `404` | `transfer-not-found` | El cliente no tiene una solicitud con ese identificador. La de otro cliente tampoco se encuentra |

El documento pendiente que escribe la aplicación:

```json
{
  "fromAccountId": "savings",
  "toAccountId": "checking",
  "amountCents": 15010,
  "concept": "Arriendo de octubre",
  "status": "pending",
  "createdAt": "<marca de tiempo del servidor>"
}
```

La aplicación solo puede crearlo, nunca modificarlo ni borrarlo. Esa regla de Firestore está propuesta y aún no desplegada; hasta entonces este camino no funciona desde la aplicación.

## Qué debe hacer la aplicación

1. Generar el `transferId` al confirmar la orden, antes de enviar nada, y guardarlo con ella.
2. Con conexión: llamar a `POST /api/transfers`. La llamada es repetible: ante un tiempo agotado o un `503`, se reenvía con el mismo `transferId`.
3. Sin conexión: escribir la solicitud pendiente en Firestore y mostrarla como «en cola». Al recuperar la conexión, y al arrancar con solicitudes pendientes, llamar a `process` por cada una.
4. Tratar `200` y `422` como resultados definitivos. `401` exige renovar el token o volver a iniciar sesión; `409` indica un error de programación en la aplicación.
5. Tras el registro, llamar a `POST /api/accounts/provision` una vez; `422 profile-required` significa que el perfil aún no se ha escrito.

## Qué escribe en Firestore

| Documento | Ruta que lo escribe | Contenido |
|---|---|---|
| `users/{uid}/transfers/{transferId}` | Transferencias | La orden, su estado, `processedAt` y `reference` o `reason` |
| `users/{uid}/accounts/{accountId}` | Transferencias | `availableCents`, `ledgerCents`, `updatedAt` |
| `users/{uid}/accounts/savings`, `checking` | Alta de cuentas | La cuenta completa |
| `users/{uid}/movements/{transferId}-out`, `{transferId}-in` | Transferencias | Un movimiento por cuenta, con la misma referencia |
| `users/{uid}/movements/opening-savings`, `opening-checking` | Alta de cuentas | El depósito de apertura |

Los nombres de los campos son los que lee la aplicación en `packages/feature_accounts`. Los clientes no pueden escribir ninguno de estos documentos salvo la solicitud pendiente.

## Cómo llega la aplicación en desarrollo

El servidor se arranca como describe [backoffice.md](backoffice.md). La dirección base se pasa a la aplicación al compilar, sin dejarla escrita en el código:

    flutter run --dart-define=API_BASE_URL=http://localhost:3000

El nombre `API_BASE_URL` es el propuesto; la aplicación todavía no lo lee.

| Dónde corre la aplicación | Dirección del servidor |
|---|---|
| Teléfono físico Android, por USB | `http://localhost:3000`, después de `adb reverse tcp:3000 tcp:3000` |
| Emulador de Android | `http://10.0.2.2:3000` |
| Simulador de iOS | `http://localhost:3000` |

`adb reverse` hace que el puerto del teléfono apunte al del equipo de desarrollo; hay que repetirlo cada vez que se reconecta el cable. No se ha comprobado si la plataforma bloquea HTTP sin cifrar hacia `localhost`: si lo hace, debe permitirse solo en la variante de depuración.

## Cómo llega en un despliegue (descrito, no realizado)

Las rutas se despliegan con la consola, sin configuración propia: usan las mismas credenciales del servidor y la misma guarda de proyecto. La aplicación se compila con la dirección pública en `API_BASE_URL`, siempre por HTTPS.

Estas rutas no comprueban el origen de la petición, porque no dependen de cookies y una aplicación móvil no envía cabecera de origen. Lo que las protege es el token. Antes de exponerlas en producción hacen falta App Check y un límite de frecuencia, que no existen.

## Operación

Cada petición deja una línea de registro en JSON:

```json
{"level":"info","requestId":"075a1da2-a50d-4658-b568-8dd0621c8119","route":"transfers.create","status":200,"outcome":"completed","durationMs":716}
```

| Campo | Valores |
|---|---|
| `route` | `transfers.create`, `transfers.process`, `accounts.provision` |
| `outcome` | `completed`, `rejected:<motivo>`, `replayed:completed`, `replayed:rejected:<motivo>`, `created`, `already-provisioned`, o el código de error |
| `level` | `error` para los estados 500 y superiores |

El registro no contiene clientes, cuentas, importes ni mensajes de error. Un error inesperado deja solo su tipo (`internal:TypeError`); uno de la base de datos, su código (`unavailable:14`). El `requestId` es el mismo que recibe la aplicación en `x-request-id`, para cruzar un informe de un cliente con su línea.

Señales a vigilar: la proporción de `replayed:*` (reintentos de la aplicación), los `rejected:insufficient-funds` y cualquier `internal:LedgerCorruptionError`, que indica una cuenta o una solicitud alterada a mano.
