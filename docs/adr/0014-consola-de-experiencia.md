# 0014. Consola de experiencia: validación desde el contrato y publicación con control de versión

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existe en `apps/backoffice` la consola de una pantalla (segmentos, módulos, banner, funcionalidades, laboratorio de resiliencia, envío de notificaciones y vista previa) con su lado de servidor, cubierta por 163 pruebas. Se ejecutó en local contra el proyecto real `flutter-challenge-bi`: se publicó la primera versión de `config/home`, se provocó un conflicto de versión y se envió una notificación en modo de prueba. **No está desplegada**, la aplicación móvil aún no escucha la configuración publicada, y ninguna notificación se ha entregado a un dispositivo. El detalle de lo verificado está al final.

## Problema a resolver

El enunciado pide que la experiencia cambie sin publicar una versión nueva de la aplicación. La aplicación ya sabe leer un documento de configuración ([ADR 0008](0008-contrato-de-configuracion.md)); falta quién lo escriba.

Escribir ese documento a mano en la consola de Firebase tiene tres riesgos: publicar algo que el contrato no admite, pisar el cambio de otra persona sin saberlo y no dejar rastro de quién cambió qué. Además, enviar una notificación exige credenciales de servidor que no pueden vivir en un cliente ([ADR 0004](0004-backoffice-y-api-en-nextjs.md)).

## Alternativas evaluadas

**Cómo se valida lo que se publica**

1. **Compilar el archivo `contracts/home-config.schema.json` tal cual, con un validador de JSON Schema.** El contrato tiene una sola redacción; un cambio en el archivo cambia lo que la consola acepta sin tocar su código.
2. **Reescribir las reglas con una biblioteca de esquemas propia de TypeScript.** Tipos más cómodos, pero dos redacciones del mismo contrato que pueden divergir.
3. **Validar solo en el navegador.** Rápido de hacer; cualquier petición directa al servidor la esquiva.

**Cómo se evita pisar el cambio de otra persona**

1. **Control optimista por versión, dentro de una transacción.** El editor envía la versión sobre la que trabajó; el servidor escribe solo si sigue siendo la publicada.
2. **Última escritura gana.** Es lo que hace el lector ([ADR 0008](0008-contrato-de-configuracion.md)) y es correcto para él, pero entre dos editores pierde trabajo en silencio.
3. **Bloqueo de edición.** Exige liberar bloqueos de sesiones abandonadas; desproporcionado para una pantalla.

**Dónde vive la lógica de edición**

1. **Funciones puras sobre el documento, fuera de los componentes.** Reordenar, ocultar y contar cambios se prueban sin navegador.
2. **Dentro de los componentes.** Menos archivos; obliga a probar cada regla a través de la interfaz.

**Cómo se demuestra el laboratorio de resiliencia sin exponerlo**

1. **Sección visible y campos aceptados solo cuando el entorno se declara de demostración.** Dos barreras del lado del publicador, más la de la aplicación ([ADR 0009](0009-politica-de-resiliencia.md)).
2. **Siempre visible.** Un documento mal publicado dejaría servicios caídos para cualquier compilación que admita fallos.

## Opción seleccionada

La primera opción en los cuatro casos.

**Validación.** `lib/config/validate.ts` compila el esquema del contrato con `ajv` y añade lo que el propio contrato enuncia en prosa porque JSON Schema no lo expresa: identificadores de módulo únicos por segmento, destinos dentro de la lista permitida a cualquier profundidad y un máximo de 32 niveles en los ajustes de un módulo. Se ejecuta en el servidor; el navegador nunca decide qué es válido.

**Publicación** (`lib/server/publish.ts`):

| Paso | Regla |
|---|---|
| Sesión | Sin sesión de administrador no se llega al almacén ([ADR 0015](0015-acceso-de-administradores.md)) |
| Validación | Un borrador que rompe el contrato se rechaza con la lista de problemas y no se escribe nada |
| Fallos simulados | Fuera de un entorno de demostración, un borrador con latencia o servicios caídos se rechaza |
| Versión | Se lee `config/home` en una transacción; si su versión no es la que cargó el editor, se rechaza como conflicto |
| Escritura | El número de versión se toma de lo almacenado más uno, nunca del navegador |
| Auditoría | En la misma transacción se añade `configAudit/v<versión>` con quién, cuándo y cuántos ajustes cambiaron |

Tras un conflicto la consola conserva las ediciones a la vista, desactiva «Publicar cambios» y pide recargar: reintentar sobre una base que ya no es la publicada repetiría el conflicto.

**Edición.** `lib/config/editing.ts` devuelve siempre un documento nuevo y conserva los campos que no conoce, de modo que un módulo añadido al contrato no se pierde al pasar por la consola. `lib/config/diff.ts` cuenta los cambios como los piensa quien edita: un reordenamiento cuenta una vez por segmento, y cada interruptor o campo, una vez.

**Vista previa.** Dibuja el inicio con los mismos módulos, orden y visibilidad del borrador, con cifras de ejemplo. Replica tres reglas de la aplicación: un tipo de módulo desconocido se omite, una funcionalidad apagada oculta sus accesos y el aviso de conexión lenta aparece a partir de 3 s de latencia. Es un boceto, no la aplicación.

**Notificaciones** (`lib/server/push.ts`). Un envío a un segmento usa el tema `segment-<id>`; un envío a un cliente busca sus dispositivos en `users/{uid}/devices`. Cada envío queda en `pushHistory` con su estado, también cuando falla, y un envío fallido se puede reintentar sobre el mismo registro. Un envío que ya salió no se reintenta. Con `PUSH_DRY_RUN=true` el servicio valida el mensaje sin entregarlo y el estado es «Validado», distinto de «Enviado».

**Dependencias de ejecución**, todas con versión fija:

| Paquete | Para qué |
|---|---|
| `next`, `react`, `react-dom` | La consola y sus rutas de servidor |
| `firebase-admin` | Firestore, sesiones y mensajería con privilegios de servidor |
| `firebase` | Solo el inicio de sesión en el navegador |
| `ajv` | Validar contra el archivo del contrato |
| `server-only` | Impedir que un módulo de servidor acabe en el paquete del navegador |

Los colores, radios y tamaños de letra salen de `packages/design_system/tokens/tokens.json`, importado en la compilación; una prueba comprueba que la hoja de estilos no usa ninguna variable que el archivo no defina.

## Trade-offs

- **Se gana:** una sola redacción del contrato, compartida por quien publica y por las pruebas del lector.
- **Se gana:** dos personas no pueden pisarse; el segundo en publicar se entera.
- **Se gana:** cada publicación deja un registro que los clientes no pueden leer ni escribir (las reglas niegan todo lo que no declaran).
- **Se paga:** el editor trabaja sobre el documento completo. Dos personas que editan segmentos distintos también entran en conflicto, aunque sus cambios no se toquen.
- **Se paga:** tras un conflicto hay que recargar y rehacer las ediciones; no hay fusión.
- **Se paga:** la auditoría guarda cuántos ajustes cambiaron, no cuáles. Reconstruir el detalle exige comparar versiones, y las versiones anteriores no se conservan.
- **Se paga:** un segundo ecosistema (Node) en el repositorio, con su propio flujo de integración continua.
- **Límite:** el recuento de clientes por segmento y el historial se cargan al abrir la consola y no se actualizan solos.
- **Límite:** no hay límite de frecuencia para envíos ni para intentos de inicio de sesión más allá del que aplica el proveedor de identidad.
- **Límite:** no se define una política de seguridad de contenido (CSP); sí se envían `X-Frame-Options`, `X-Content-Type-Options` y `Referrer-Policy`.
- **Límite:** `npm audit` informa avisos en dependencias transitivas sin corrección compatible disponible: `@grpc/grpc-js` (lo trae el SDK web de Firebase para Firestore, que la consola no usa en el navegador) y `uuid` (lo trae la autenticación de Google en el servidor). Los avisos de `braces` afectan solo a herramientas de desarrollo.
- **Límite:** la accesibilidad se comprobó con pruebas por rol y nombre, y el reordenamiento funciona con teclado mediante los botones. No se hizo una revisión con lector de pantalla.

## Impacto a largo plazo

Añadir un tipo de módulo o un destino es un cambio en `contracts/`: la consola lo acepta y lo muestra con su identificador hasta que `lib/config/labels.ts` le dé un nombre. Añadir una funcionalidad es una clave en el contrato y una etiqueta.

Si varios equipos editan a la vez, el documento único se queda corto. El siguiente paso sería un documento por segmento, o por dominio, cada uno con su versión; el control optimista y la auditoría se mantienen igual.

La auditoría es la base de una reversión: guardar el documento anterior junto a cada entrada permitiría «volver a la versión N» como una publicación más. Se dejó fuera a propósito.

## Qué se verificó y qué no

Verificado el 2026-10-03 en local, con la compilación de producción (`next start`), contra el proyecto real:

- Sin sesión, la consola redirige al inicio de sesión; `POST /api/push` responde 401 y una petición de otro origen o sin origen, 403.
- Una contraseña incorrecta y un token inventado reciben la misma respuesta.
- La primera publicación creó `config/home` con la versión 1 y la entrada `configAudit/v1`.
- Con la versión cambiada por fuera durante la edición, la publicación se rechazó, el documento no cambió y la consola mostró el conflicto.
- Un envío en modo de prueba a un segmento fue aceptado por el servicio de mensajería y quedó como «Validado»; un envío a un cliente inexistente quedó como «Fallido».

Sin verificar:

- La entrega real de una notificación: la aplicación aún no registra dispositivos ni se suscribe a temas.
- Que la aplicación refleje una publicación: aún no escucha `config/home`.
- El reintento de un envío fallido contra el servicio real y el rechazo de fallos simulados fuera de demostración; ambos están cubiertos solo por pruebas.
- El arrastre con el puntero; en la verificación se usaron los botones.
- El despliegue y el flujo de integración continua, que nunca se ha ejecutado.
