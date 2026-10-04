# Consola de experiencia: configuración, ejecución, pruebas y despliegue

La consola vive en `apps/backoffice`. Es una aplicación Next.js con su propio `package.json`; no forma parte del workspace de Dart. Las decisiones están en [ADR 0014](../adr/0014-consola-de-experiencia.md) y [ADR 0015](../adr/0015-acceso-de-administradores.md).

**Estado:** se ejecuta en local contra el proyecto real. No está desplegada; la sección de despliegue describe cómo se haría y no se ha ejecutado.

## Requisitos

- Node.js 22 o posterior (se desarrolló con 24).
- Acceso al proyecto de Firebase `flutter-challenge-bi` con una cuenta de Google.
- Google Cloud CLI, para las credenciales de desarrollo.

## Configuración

Las variables se leen del entorno. En desarrollo van en `apps/backoffice/.env.local`, que git ignora. **Ese archivo no se versiona nunca**; el repositorio es público.

| Variable | Dónde se usa | Valor |
|---|---|---|
| `FIREBASE_PROJECT_ID` | Servidor | `flutter-challenge-bi`. Con otro valor el servidor no arranca |
| `ALLOW_OTHER_PROJECT` | Servidor | `true` solo para apuntar a otro proyecto a propósito |
| `ADMIN_EMAILS` | Servidor | Direcciones admitidas, separadas por comas. Obligatoria |
| `BACKOFFICE_ENVIRONMENT` | Servidor | `demo` muestra el laboratorio de resiliencia y permite publicarlo. Cualquier otro valor lo oculta y el servidor rechaza fallos simulados |
| `PUSH_DRY_RUN` | Servidor | `true` valida cada envío sin entregarlo |
| `FIREBASE_SERVICE_ACCOUNT` | Servidor | Cuenta de servicio en una línea de JSON. Vacía en desarrollo |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Navegador | Identificador público de la aplicación web de Firebase |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Navegador | Ídem |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Navegador | Ídem |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | Navegador | Ídem |

Los cuatro valores del navegador son identificadores de cliente, no credenciales, y se obtienen con:

```bash
firebase apps:sdkconfig WEB --project flutter-challenge-bi
```

Se incorporan al paquete del navegador durante la compilación, así que deben estar presentes al ejecutar `npm run build`.

### Credenciales del servidor en desarrollo

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

El flujo `.github/workflows/backoffice.yml` ejecuta lint, compilación, comprobación de tipos y pruebas cuando cambia `apps/backoffice`, `contracts` o los tokens del sistema de diseño. La compilación va antes de la comprobación de tipos porque genera los tipos de las rutas.

El hook de pre-commit del repositorio no ejecuta estas pruebas; antes de un commit que toque la consola hay que correr `npm run verify`.

## Qué escribe en Firestore

| Ruta | Contenido | Acceso de clientes |
|---|---|---|
| `config/home` | La configuración publicada | Lectura con sesión; sin escritura |
| `configAudit/v<versión>` | Quién publicó, cuándo y cuántos ajustes cambiaron | Ninguno |
| `pushHistory/<id>` | Cada envío: título, mensaje, audiencia, destino, estado, intentos | Ninguno |

Las dos últimas colecciones no aparecen en las reglas, que niegan todo lo que no declaran. Un envío a un cliente guarda su identificador de usuario, no su correo.

Para enviar a un cliente, la consola lee sus dispositivos de `users/{uid}/devices/*`, campo `token`. Para enviar a un segmento usa el tema `segment-<id del segmento>`. La aplicación móvil todavía no escribe esos documentos ni se suscribe a esos temas.

## Despliegue (descrito, no realizado)

La consola necesita un entorno Node con las variables de la tabla. En cualquier proveedor:

1. Directorio raíz del proyecto: `apps/backoffice`, con acceso de compilación a la raíz del repositorio, porque importa `contracts/` y `packages/design_system/tokens/`.
2. Variables de servidor como secretos del proveedor, incluida `FIREBASE_SERVICE_ACCOUNT` con una cuenta de servicio limitada a Firestore, autenticación y mensajería del proyecto.
3. Variables `NEXT_PUBLIC_*` disponibles en la compilación.
4. `BACKOFFICE_ENVIRONMENT` distinto de `demo` salvo en el entorno de la demostración.
5. Solo HTTPS: la cookie de sesión se marca `Secure` en producción.

Antes de dar por bueno un despliegue habría que comprobar lo que hoy solo cubren las pruebas: que sin sesión no se accede a nada, que un entorno que no es de demostración rechaza fallos simulados y que la cuenta de servicio no puede hacer más de lo necesario.

## Operación

- **Una publicación falla con conflicto:** alguien publicó antes. Recargar y repetir las ediciones.
- **Una publicación falla sin motivo aparente:** el almacén no respondió. Las ediciones siguen en pantalla; reintentar.
- **Revertir una publicación:** no hay botón. Se edita de nuevo y se publica; la auditoría dice qué versión publicó cada persona.
- **Retirar el acceso a alguien:** quitar su dirección de `ADMIN_EMAILS` y reiniciar. Surte efecto en su siguiente petición. Si la cuenta está comprometida, además deshabilitarla en Firebase Authentication.
- **Un envío queda como «Fallido»:** el registro guarda el código de error del servicio. «Reintentar» lo envía de nuevo sobre el mismo registro.
