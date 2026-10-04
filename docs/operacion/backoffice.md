# Consola de experiencia: configuración, ejecución, pruebas y despliegue

La consola vive en `apps/backoffice`. Es una aplicación Next.js con su propio `package.json`; no forma parte del workspace de Dart. Las decisiones están en [ADR 0014](../adr/0014-consola-de-experiencia.md) y [ADR 0015](../adr/0015-acceso-de-administradores.md).

**Estado:** se ejecuta en local contra el proyecto real. No está desplegada; la sección de despliegue describe cómo se haría y no se ha ejecutado.

## Requisitos

- Node.js 22 o posterior (se desarrolló con 24).
- Acceso al proyecto de Firebase `flutter-challenge-bi` con una cuenta de Google.
- Google Cloud CLI, para las credenciales de desarrollo.

## Configuración

Las variables se leen del entorno. En desarrollo van en un archivo `apps/backoffice/.env.local` que cada persona crea a mano y que git ignora. **Ese archivo no se versiona nunca**; el repositorio es público. No hay un archivo de ejemplo en el repositorio: la lista completa de variables es la tabla siguiente.

| Variable | Dónde se usa | Valor |
|---|---|---|
| `FIREBASE_PROJECT_ID` | Servidor | `flutter-challenge-bi`. Con otro valor el servidor no arranca |
| `ALLOW_OTHER_PROJECT` | Servidor | `true` solo para apuntar a otro proyecto a propósito |
| `ADMIN_EMAILS` | Servidor | Direcciones admitidas, separadas por comas. Obligatoria |
| `BACKOFFICE_ENVIRONMENT` | Servidor | `demo` muestra el laboratorio de resiliencia y permite publicarlo. Con cualquier otro valor se oculta y el servidor rechaza añadir o agravar fallos simulados; quitarlos sigue permitido |
| `PUSH_DELIVERY` | Servidor | `live` entrega las notificaciones a los teléfonos. Sin la variable, o con cualquier otro valor, cada envío solo se valida y no se entrega |
| `FIREBASE_SERVICE_ACCOUNT` | Servidor | Cuenta de servicio en una línea de JSON. Vacía en desarrollo. Solo debe existir en el almacén de secretos del proveedor de despliegue |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Navegador | Identificador público de la aplicación web de Firebase |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Navegador | Ídem |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Navegador | Ídem |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | Navegador | Ídem |

Los cuatro valores del navegador son identificadores de cliente, no credenciales, y se obtienen con:

```bash
firebase apps:sdkconfig WEB --project flutter-challenge-bi
```

Se incorporan al paquete del navegador durante la compilación, así que deben estar presentes al ejecutar `npm run build`.

### Modo local, sin credenciales

`tool/local-stack.sh up` arranca los emuladores de Auth y Firestore y este servidor apuntando a ellos, en el puerto 3210; `tool/local-stack.sh seed` crea un administrador y un cliente locales y publica la configuración. No necesita acceso al proyecto de Firebase ni credenciales de Google. El script pone por sí mismo las variables de la tabla anterior, además de:

| Variable | Valor en el modo local | Efecto |
| --- | --- | --- |
| `FIREBASE_AUTH_EMULATOR_HOST`, `FIRESTORE_EMULATOR_HOST` | `127.0.0.1:9099`, `127.0.0.1:8080` | El servidor usa los emuladores, sin credenciales |
| `NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_URL` | `http://127.0.0.1:9099` | El inicio de sesión de la consola usa el emulador de Auth |
| `BACKOFFICE_ENVIRONMENT` | `demo` | Muestra el laboratorio de resiliencia |

Dos diferencias con el proyecto real:

- **Servidor de desarrollo.** Se usa `next dev`, porque con `NODE_ENV=production` el servidor se niega a arrancar si ve variables de emulador: un emulador acepta tokens que nadie firmó.
- **Notificaciones.** El servicio de mensajería no tiene emulador. Con los emuladores activos, cada envío se acepta en el momento como validación y no sale del equipo; queda «Validado» y no escribe la bandeja. El aviso de una transferencia completada sí se escribe en la bandeja.

### Credenciales del servidor en desarrollo, contra el proyecto real

No hace falta ningún archivo de clave:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project flutter-challenge-bi
```

En la pantalla de consentimiento hay que marcar el permiso de Google Cloud; sin él, el comando termina con error.

### Alta de un administrador

La consola solo admite una dirección que esté en `ADMIN_EMAILS` y además verificada. Una cuenta creada desde la aplicación móvil no está verificada y no sirve. La cuenta se crea con la herramienta de administración de Firebase, marcada como verificada, y su dirección se añade a `ADMIN_EMAILS`.

## Ejecución

```bash
cd apps/backoffice
npm ci
npm run dev        # http://localhost:3000
```

Para ejecutar la compilación de producción en local:

```bash
npm run build
npm run start
```

Al abrir la consola sin sesión se redirige a `/login`. Si `config/home` no existe todavía, el editor se abre con el ejemplo del contrato y la primera publicación crea el documento con la versión 1.

## Pruebas

```bash
npm run lint        # ESLint
npm run typecheck   # TypeScript en modo estricto
npm run test        # Vitest: lógica, rutas de servidor y componentes
npm run verify      # todo lo anterior más la compilación
```

Las pruebas no necesitan credenciales ni red: el SDK de administración se sustituye por dobles.

| Qué cubren | Dónde |
|---|---|
| Validación contra el contrato | `lib/config/validate.test.ts` |
| Reordenar, ocultar, banner, funcionalidades, fallos | `lib/config/editing.test.ts` |
| Recuento de cambios | `lib/config/diff.test.ts` |
| Estado del editor y de la publicación | `lib/console/editor-state.test.ts` |
| Publicación: versión, conflicto, auditoría, entorno | `lib/server/publish.test.ts`, `app/actions.test.ts` |
| Sesión y caminos denegados | `lib/server/session.test.ts`, `app/api/session/route.test.ts`, `lib/server/same-origin.test.ts` |
| Notificaciones: envío, registro, reintento | `lib/server/push.test.ts`, `app/api/push/route.test.ts` |
| Ajustes del servidor y guarda de proyecto | `lib/server/settings.test.ts` |
| Estados de publicación y pantalla completa | `components/console/top-bar.test.tsx`, `components/console/console.test.tsx` |
| Laboratorio de resiliencia e historial de envíos | `components/console/settings-cards.test.tsx`, `components/console/push-card.test.tsx` |

El flujo `.github/workflows/backoffice.yml` ejecuta lint, compilación, comprobación de tipos y pruebas cuando cambia `apps/backoffice`, `contracts` o los tokens del sistema de diseño. La compilación va antes de la comprobación de tipos porque genera los tipos de las rutas.

El hook de pre-commit del repositorio no ejecuta estas pruebas; antes de un commit que toque la consola hay que correr `npm run verify`.

### Dependencias

Las actualizaciones se revisan a mano: `npm audit` y `npm outdated` desde `apps/backoffice`, y cada cambio de versión entra como un commit revisado. No hay un bot que abra peticiones de actualización para este directorio. Dos dependencias transitivas se fijan con `overrides` en `package.json` a versiones corregidas; al actualizar `firebase` o `firebase-admin` conviene comprobar si siguen haciendo falta.

## Qué escribe en Firestore

| Ruta | Contenido | Acceso de clientes |
|---|---|---|
| `config/home` | La configuración publicada | Lectura con sesión; sin escritura |
| `configAudit/v<versión>` | Quién publicó, cuándo y cuántos ajustes cambiaron | Ninguno |
| `pushHistory/<id>` | Cada envío: título, mensaje, audiencia, destino, estado, intentos y dispositivos alcanzados | Ninguno |
| `users/{uid}/devices/<id>` | Solo los campos `unregistered` y `unregisteredAt`, en un dispositivo que el servicio de mensajería ya no reconoce | Lo define la etapa de notificaciones |

`configAudit` y `pushHistory` no aparecen en las reglas, que niegan todo lo que no declaran. Un envío a un cliente guarda su identificador de usuario, no su correo; si no se pudo alcanzar a nadie, no guarda ninguno de los dos.

Para enviar a un cliente, la consola lee sus dispositivos de `users/{uid}/devices/*`, campo `token`, y deja fuera los marcados como `unregistered`. Nunca borra un documento de dispositivo. Para enviar a un segmento usa el tema `segment-<id del segmento>`.

**Pendiente en la etapa de notificaciones.** La aplicación móvil todavía no escribe esos documentos ni se suscribe a esos temas. Para que pueda registrar su dispositivo hará falta una regla de Firestore que permita a cada cliente escribir en su propio `users/{uid}/devices`; hoy las reglas niegan toda escritura en subcolecciones. Esa regla pertenece a esa etapa y no se ha añadido aquí.

## Despliegue (descrito, no realizado)

La consola necesita un entorno Node con las variables de la tabla. En cualquier proveedor:

1. Directorio raíz del proyecto: `apps/backoffice`, con acceso de compilación a la raíz del repositorio, porque importa `contracts/` y `packages/design_system/tokens/`.
2. Variables de servidor como secretos del proveedor, incluida `FIREBASE_SERVICE_ACCOUNT` con una cuenta de servicio limitada a Firestore, autenticación y mensajería del proyecto. Ese JSON solo debe vivir en el almacén de secretos del proveedor: no se guarda en el repositorio, ni en un archivo de entorno, ni se pega en un terminal cuyo historial se conserve.
3. Variables `NEXT_PUBLIC_*` disponibles en la compilación.
4. `BACKOFFICE_ENVIRONMENT` distinto de `demo` salvo en el entorno de la demostración.
5. `PUSH_DELIVERY=live` solo en el entorno que deba notificar a clientes reales. Sin ella, la consola funciona entera pero no entrega nada.
6. Solo HTTPS: la cookie de sesión se marca `Secure` en producción.

Antes de dar por bueno un despliegue habría que comprobar lo que hoy solo cubren las pruebas: que un entorno que no es de demostración rechaza añadir fallos simulados, que sin `PUSH_DELIVERY=live` no se entrega ninguna notificación y que la cuenta de servicio no puede hacer más de lo necesario.

## Operación

- **Una publicación falla con conflicto:** alguien publicó antes. «Publicar cambios» queda desactivado hasta recargar; después hay que repetir las ediciones.
- **La consola avisa de fallos simulados activos:** se publicaron desde un entorno de demostración. «Quitar fallos simulados» los pone a cero en el borrador; después se publica.
- **Cerrar sesión:** cierra la sesión de ese administrador en todos sus navegadores, no solo en el actual.
- **Una publicación falla sin motivo aparente:** el almacén no respondió. Las ediciones siguen en pantalla; reintentar.
- **Revertir una publicación:** no hay botón. Se edita de nuevo y se publica; la auditoría dice qué versión publicó cada persona.
- **Retirar el acceso a alguien:** quitar su dirección de `ADMIN_EMAILS` y reiniciar. Surte efecto en su siguiente petición. Si la cuenta está comprometida, además deshabilitarla en Firebase Authentication.
- **Un envío queda como «Fallido»:** el registro guarda el código de error del servicio. «Reintentar» lo envía de nuevo sobre el mismo registro, una sola vez aunque dos personas pulsen a la vez. Un envío a un cliente al que no se pudo alcanzar no ofrece reintento: hay que redactarlo de nuevo.
- **Un envío queda como «Reintentando» y no cambia:** el servidor se interrumpió durante el reintento. A los 2 minutos se puede reintentar otra vez.
- **Un envío queda como «Entrega parcial»:** llegó a parte de los dispositivos del cliente. No se reintenta, para no duplicarlo en los que sí lo recibieron.
- **Un envío queda como «Validado»:** el entorno no tiene `PUSH_DELIVERY=live`; el servicio aceptó el mensaje y no entregó nada.
