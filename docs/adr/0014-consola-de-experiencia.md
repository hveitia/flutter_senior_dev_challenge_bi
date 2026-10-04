# 0014. Consola de experiencia: validación desde el contrato y publicación con control de versión

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existe en `apps/backoffice` la consola, dividida en secciones con un menú superior (inicio con módulos y banner, funcionalidades, laboratorio de resiliencia y envío de notificaciones, más la lista de segmentos y la vista previa) con su lado de servidor, cubierta por pruebas automáticas (el número actual está en el README). Dos revisiones independientes (fiabilidad y riesgo) dieron lugar a las correcciones que este documento ya recoge. Se ejecutó en local contra el proyecto real `flutter-challenge-bi`: se publicó la primera versión de `config/home`, se provocó un conflicto de versión y se envió una notificación en modo de prueba. Después se desplegó en Firebase App Hosting ([operación](../operacion/backoffice.md#despliegue-en-firebase-app-hosting)); la aplicación móvil ya escucha la configuración publicada y recibe notificaciones enviadas desde la consola en local. Para ese despliegue, el contrato y los tokens de diseño dejaron de importarse desde fuera de la carpeta de la consola: se copian a `shared/` antes de cada compilación y prueba, con una prueba que compara las copias con sus fuentes, que siguen siendo únicas. El detalle de lo verificado está al final.

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
| Tamaño | Un borrador de más de 256 KB serializado se rechaza antes de validarlo |
| Validación | Un borrador que rompe el contrato se rechaza con la lista de problemas y no se escribe nada |
| Versión | Se lee `config/home` en una transacción; si su versión no es la que cargó el editor, se rechaza como conflicto |
| Fallos simulados | Fuera de un entorno de demostración se rechaza un borrador que añade un fallo o agrava uno publicado; mantenerlos o reducirlos se permite |
| Escritura | El número de versión se toma de lo almacenado más uno, nunca del navegador |
| Auditoría | En la misma transacción se añade `configAudit/v<versión>` con quién, cuándo y cuántos ajustes cambiaron |

Tras un conflicto la consola conserva las ediciones a la vista, desactiva «Publicar cambios» y pide recargar: reintentar sobre una base que ya no es la publicada repetiría el conflicto. El bloqueo se mantiene aunque se siga editando o se descarte; solo recargar lo levanta.

Mientras una publicación está en curso, los controles de edición quedan desactivados: lo que hay en pantalla es exactamente lo que se envió, y es eso lo que se da por publicado al recibir la respuesta.

**Documento almacenado inválido.** Si `config/home` no cumple el contrato (le faltan los segmentos, por ejemplo), la consola se abre sobre el ejemplo del contrato con la versión almacenada como base, y publicar lo repara. El recuento de cambios de esa publicación es cero, porque no hay un documento válido con el que comparar.

**Fallos simulados fuera de demostración.** La regla «ni añadir ni agravar» sustituye a «ninguno»: con la regla anterior, un fallo publicado desde un entorno de demostración habría bloqueado todas las publicaciones posteriores de un entorno que no lo es, incluida la que lo quita. Como allí el laboratorio no se muestra, la consola avisa de que hay fallos activos y ofrece «Quitar fallos simulados». En el laboratorio, una latencia publicada por encima del rango habitual del control (8 s) se muestra con su valor real y alarga el control.

**Edición.** `lib/config/editing.ts` devuelve siempre un documento nuevo y conserva los campos que no conoce, de modo que un módulo añadido al contrato no se pierde al pasar por la consola. `lib/config/diff.ts` cuenta los cambios como los piensa quien edita: un reordenamiento cuenta una vez por segmento, y cada interruptor o campo, una vez.

**Vista previa.** Dibuja el inicio con los mismos módulos, orden y visibilidad del borrador, con cifras de ejemplo. Replica tres reglas de la aplicación: un tipo de módulo desconocido se omite, una funcionalidad apagada oculta sus accesos y el aviso de conexión lenta aparece a partir de 3 s de latencia. Es un boceto, no la aplicación.

**Notificaciones** (`lib/server/push.ts`). Un envío a un segmento usa el tema `segment-<id>`; un envío a un cliente busca sus dispositivos en `users/{uid}/devices`. Cada envío queda en `pushHistory` con su estado, también cuando falla.

| Estado | Significado |
|---|---|
| Enviado | El servicio aceptó el envío para todos los destinatarios |
| Entrega parcial | Llegó a algunos dispositivos del cliente y a otros no; se guarda cuántos |
| Validado | Envío en modo de prueba: el servicio lo validó y no entregó nada |
| Fallido | No se entregó; se guarda el código de error del servicio |
| Reintentando | Alguien lo está enviando de nuevo en este momento |

- **Entrega real solo si se pide.** El servidor entrega únicamente con `PUSH_DELIVERY=live`. Sin esa variable, o con cualquier otro valor, valida sin entregar: un despliegue sin configurar no puede notificar a clientes por descuido.
- **Reintento reclamado en una transacción.** Reintentar pasa el registro de «Fallido» a «Reintentando» antes de enviar. De dos clics, o de dos administradores, solo envía quien consigue el cambio. Si el servidor muere entre reclamar y registrar el resultado, el registro vuelve a poder reintentarse a los 2 minutos.
- **Un envío parcial no se reintenta:** repetirlo entregaría dos veces a los dispositivos que sí lo recibieron.
- **Dispositivos dados de baja.** Los que el servicio informa como no registrados se marcan (`unregistered`) y dejan de usarse; la consola no borra documentos de dispositivo.
- **Una sola respuesta para un cliente inalcanzable.** Una dirección que no es de un cliente y un cliente sin dispositivo dan el mismo resultado, en pantalla y en lo almacenado (sin identificador de usuario), para que el historial no sirva para averiguar qué direcciones son de clientes. Ese registro no se puede reintentar, porque ya no dice a quién iba.

**Dependencias de ejecución**, todas con versión fija:

| Paquete | Para qué |
|---|---|
| `next`, `react`, `react-dom` | La consola y sus rutas de servidor |
| `firebase-admin` | Firestore, sesiones y mensajería con privilegios de servidor |
| `firebase` | Solo el inicio de sesión en el navegador |
| `ajv` | Validar contra el archivo del contrato |
| `server-only` | Impedir que un módulo de servidor acabe en el paquete del navegador |

Los colores, radios y tamaños de letra salen de `packages/design_system/tokens/tokens.json`, importado en la compilación; una prueba comprueba que la hoja de estilos no usa ninguna variable que el archivo no defina.

### Navegación por secciones

La consola empezó como una sola pantalla con todas las tarjetas en columna. Al usarla desplegada, el desplazamiento resultó demasiado largo y se dividió en secciones con un menú superior: Inicio (módulos y banner), Funcionalidades, Resiliencia y Notificaciones.

- **Un solo borrador, editado desde varias secciones.** Una sección decide qué se ve, no qué se edita: el borrador, el segmento elegido y el estado de publicación pertenecen al editor entero. Por eso el contador de cambios, «Publicar cambios», «Descartar» y el aviso de un fallo o de un conflicto están en la barra superior, a la vista desde cualquier sección, y se publica todo de una vez. La alternativa, un borrador y una publicación por sección, habría multiplicado las versiones y los conflictos sin dar nada a cambio.
- **Las secciones siguen montadas.** Solo se muestra la abierta. Así, lo escrito en otra, incluido el texto de una notificación a medio redactar, sigue ahí al volver, y cambiar de sección no pide nada al servidor.
- **El menú dice dónde hay cambios sin publicar.** Cada entrada lleva una marca, también en texto para lectores de pantalla. La cuenta por sección y el contador total salen de la misma función, de modo que no pueden discrepar.
- **La sección va en la dirección**, como parámetro de consulta (`?seccion=funcionalidades`). Se eligió el parámetro y no un segmento de ruta porque un cambio de ruta volvería a ejecutar la página en el servidor, que es donde se lee la configuración: el borrador en curso se quedaría atrás respecto de lo recién leído. Con el parámetro, el cambio ocurre en el navegador, el botón de retroceso vuelve a la sección anterior y una recarga o un enlace compartido abren la misma. Un valor desconocido, o una sección que el entorno no tiene, abre la primera.
- **Resiliencia existe solo en demostración.** Fuera de ella no aparece en el menú ni se puede abrir por su dirección. El aviso de que la configuración publicada tiene fallos activos, que afecta a cualquier publicación, se muestra sobre todas las secciones.
- **La vista previa acompaña a lo que cambia el inicio.** Queda fija junto al contenido en las tres secciones cuyas ediciones se ven en el teléfono y no aparece en Notificaciones. La lista de segmentos explica en cada sección qué significa elegir uno: en Resiliencia, por ejemplo, los ajustes valen para todos y el segmento solo cambia la vista previa.
- **Abrir una sección lleva a ella.** La página vuelve arriba y el foco pasa al título de la sección, también al volver con el botón de retroceso. El título se puede enfocar desde el código pero no es una parada del tabulador. Un lector de pantalla lo lee al recibir el foco, por lo que la región de avisos no lo repite.
- **Recargar sí pierde el borrador, y el navegador pregunta antes.** Mientras hay cambios sin publicar, una recarga o el cierre de la pestaña muestran la confirmación estándar del navegador. Se registra solo en ese caso y se retira al publicar o descartar; cambiar de sección no pasa por ella.
- **La lectura de la dirección va dentro de un límite de suspensión** en la página, con un contenido de espera que no nombra ninguna sección. La página sigue generándose en cada petición, porque lee la sesión.
- **La protección no cambia.** La sección es solo presentación: la página sigue comprobando la sesión antes de leer nada, y cada acción y ruta, por su cuenta.

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
- **Límite:** un envío a un cliente que sí tiene dispositivos se distingue de uno inalcanzable, así que un envío logrado confirma que la dirección es de un cliente. Es inherente a la función; lo que se evita es distinguir los dos casos de fallo.
- **Límite:** el límite de 256 KB es del borrador completo. El contrato no acota todavía el número de módulos ni la longitud de los textos; las cotas propuestas están pendientes de aplicarse en `contracts/`.
- **Dependencias:** dos dependencias transitivas con avisos de seguridad (`@grpc/grpc-js` y `uuid`) se elevan a versiones corregidas con `overrides` en `package.json`; con ello `npm audit --omit=dev` no informa avisos. Quedan avisos de `braces`, sin versión corregida, que solo afectan a herramientas de desarrollo. Las actualizaciones de dependencias se revisan a mano con `npm audit`; no se automatizan con un bot para que cada cambio del repositorio tenga un autor que lo haya revisado.
- **Límite:** la accesibilidad se comprobó con pruebas por rol y nombre. El reordenamiento funciona con teclado mediante los botones, el foco sigue al módulo movido, y su nueva posición y cada publicación lograda se anuncian en una región viva. No se hizo una revisión con un lector de pantalla real.

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

Verificado de nuevo tras las correcciones de la revisión, del mismo modo:

- Tras un conflicto, otra edición no reactiva «Publicar cambios» y el aviso sigue visible.
- Tras recargar, una publicación y su reversión se aplicaron, y la región viva anunció la versión publicada.
- Después de cerrar sesión, la cookie anterior, que hasta ese momento daba acceso, se rechazó: la consola redirige al inicio de sesión y `POST /api/push` responde 401.

Verificado tras dividir la consola en secciones, en un navegador contra el modo local con emuladores (servidor en modo de desarrollo):

- Cada sección abre con su dirección; cuatro cambios de sección seguidos no produjeron ninguna petición al servidor.
- Una edición hecha en Inicio y otra en Funcionalidades seguían contadas desde Notificaciones («2 cambios sin publicar»), con las dos secciones marcadas en el menú, y se publicaron desde allí.
- El botón de retroceso volvió a la sección anterior sin perder el borrador; una recarga abrió la sección de la dirección y un valor desconocido abrió Inicio.
- A 1280, 1024 y 768 píxeles de ancho no hay desbordamiento horizontal. A 1280 por 800, Funcionalidades, Resiliencia y Notificaciones caben sin desplazamiento; Inicio necesita uno corto para llegar al banner.

- Al abrir una sección con el teclado, el foco quedó en su título y la página arriba; el siguiente tabulador llegó al primer control de la sección. Lo mismo tras el botón de retroceso.
- Con un cambio sin publicar, la recarga mostró la confirmación del navegador; con el borrador limpio, tras descartar y al cambiar de sección, no.

La compilación de producción no puede comprobarse contra los emuladores: el servidor los rechaza en producción a propósito ([ADR 0015](0015-acceso-de-administradores.md)).

Sin verificar:

- Las secciones con un lector de pantalla real; los nombres accesibles, el punto de salto al contenido y los anuncios están cubiertos por pruebas. En el servidor desplegado el autor inició sesión como administrador, recorrió las secciones y publicó un cambio que se reflejó en el teléfono.
- Un envío real de notificación desde el servidor desplegado y el laboratorio de resiliencia publicado desde la consola desplegada.
- La entrega parcial y el marcado de dispositivos dados de baja, que solo están cubiertos por pruebas. La entrega real a un cliente y a un segmento sí se vio después en un teléfono ([ADR 0018](0018-notificaciones-y-bandeja.md)), igual que el reflejo de una publicación en el inicio ([ADR 0013](0013-registro-de-modulos-y-motor-del-inicio.md)).
- El reintento de un envío fallido contra el servicio real, incluida la reclamación en transacción, y el rechazo de fallos simulados fuera de demostración; están cubiertos solo por pruebas.
- El arrastre con el puntero; en la verificación se usaron los botones.
