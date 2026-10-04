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
| `FIREBASE_SERVICE_ACCOUNT` | Servidor | Cuenta de servicio en una línea de JSON. Vacía en desarrollo y en Firebase App Hosting, donde se usan las credenciales de la plataforma. Solo para un proveedor sin identidad propia, y entonces solo en su almacén de secretos |
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

## Despliegue en Firebase App Hosting (preparado, no realizado)

**A la fecha de este documento no se ha desplegado.** El proyecto no tiene activado el plan de pago por uso, que App Hosting exige. Lo que sigue es el procedimiento preparado; los pasos marcados con (navegador) necesitan a la persona propietaria del proyecto.

Se eligió App Hosting porque el servidor corre con la identidad de servicio del propio proyecto: no hay clave de cuenta de servicio ([ADR 0015](../adr/0015-acceso-de-administradores.md)). Un solo servidor atiende la consola, la API de clientes y las páginas de los aliados.

### Qué está comprobado y qué no

Comprobado en un contenedor Linux (`node:24`), sobre una copia limpia del repositorio y sin credenciales de Google:

- `npm ci` y `next build` desde `apps/backoffice`, también con salida autónoma (`standalone`), que es la que pide un adaptador de alojamiento.
- El contrato y los tokens de diseño se incorporan al compilar: el servidor en ejecución no lee ningún archivo de fuera de su carpeta.
- Con solo las variables de la tabla de abajo, el servidor arranca y responde: `/api/health` 200, `/login` 200, `/` redirige al inicio de sesión, una página de aliado 200 con su política de referencia, y la API de clientes 401 sin token.
- Con una variable de emulador y la marca de la plataforma, la configuración se declara inválida (`/api/health` 503).

Solo la plataforma real puede comprobar:

- que la compilación de App Hosting, con `apps/backoffice` como directorio raíz, tiene acceso al resto del repositorio (importa `contracts/` y `packages/design_system/tokens/`);
- que las credenciales por defecto de la plataforma bastan para Firestore, autenticación y mensajería, y con qué permisos;
- que el proxy de la plataforma envía el host público en `x-forwarded-host`, del que depende la comprobación de origen de las rutas que cambian estado;
- el enlace de los secretos y de las variables de compilación.

### Variables y secretos

Definidos en `apps/backoffice/apphosting.yaml`. Ningún valor sensible está en el repositorio.

| Variable | Tipo | Disponible en | Valor |
|---|---|---|---|
| `FIREBASE_PROJECT_ID` | Valor | Ejecución | `flutter-challenge-bi` |
| `BACKOFFICE_ENVIRONMENT` | Valor | Ejecución | `demo`: muestra el laboratorio de resiliencia |
| `PUSH_DELIVERY` | Valor | Ejecución | `live`: entrega real de notificaciones |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Valor | Compilación y ejecución | `flutter-challenge-bi` |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Valor | Compilación y ejecución | `flutter-challenge-bi.firebaseapp.com` |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Secreto `backoffice-web-api-key` | Compilación y ejecución | Identificador público de la aplicación web. No es confidencial; va como secreto para que el análisis de secretos del repositorio no lo marque |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | Secreto `backoffice-web-app-id` | Compilación y ejecución | Ídem |
| `ADMIN_EMAILS` | Secreto `backoffice-admin-emails` | Ejecución | Direcciones admitidas en la consola. Dato personal |
| `FIREBASE_SERVICE_ACCOUNT` | No se define | | En App Hosting no existe: se usan las credenciales de la plataforma |

Cupo: `maxInstances: 2`, sin instancias mínimas. Una demostración no necesita escalar, y el tope acota lo que puede costar un pico de tráfico.

### Pasos, en orden

1. **(navegador)** Activar el plan Blaze en el proyecto y crear una alerta de presupuesto: <https://console.firebase.google.com/project/flutter-challenge-bi/usage/details>.
2. Obtener los identificadores de la aplicación web, que ya existe en el proyecto:

   ```bash
   firebase apps:sdkconfig WEB --project flutter-challenge-bi
   ```

3. **(navegador)** Crear el servidor. El asistente pide conectar el repositorio de GitHub e instalar la aplicación de Firebase en él, y elegir la rama (`main`):

   ```bash
   firebase apphosting:backends:create --project flutter-challenge-bi \
     --backend backoffice --root-dir apps/backoffice --primary-region us-east4
   ```

   La región es una propuesta; el asistente lista las disponibles.
4. Crear los tres secretos. Cada orden pide el valor sin dejarlo en el historial del terminal:

   ```bash
   firebase apphosting:secrets:set backoffice-web-api-key --project flutter-challenge-bi
   firebase apphosting:secrets:set backoffice-web-app-id --project flutter-challenge-bi
   firebase apphosting:secrets:set backoffice-admin-emails --project flutter-challenge-bi
   firebase apphosting:secrets:grantaccess \
     backoffice-web-api-key,backoffice-web-app-id,backoffice-admin-emails \
     --backend backoffice --project flutter-challenge-bi
   ```

5. Desplegar. Cada push a `main` despliega; a mano:

   ```bash
   firebase apphosting:rollouts:create backoffice --git-branch main --project flutter-challenge-bi
   ```

6. Comprobar `https://<servidor>.hosted.app/api/health` (200 y `"configuration":"valid"`), que `/` redirige a `/login` y que `POST /api/transfers` sin token responde 401.
7. **(navegador)** Si el inicio de sesión de la consola lo exige, añadir el dominio `*.hosted.app` del servidor a los dominios autorizados de Authentication.
8. Crear la cuenta del revisor (siguiente apartado), iniciar sesión, publicar un cambio y verlo llegar a la aplicación.

### Cuenta de administrador para un revisor

La cuenta debe estar en `ADMIN_EMAILS` y tener el correo verificado. Se crea con credenciales de la persona propietaria, sin escribir la contraseña en ningún archivo ni en el historial:

```bash
read -r -s -p "Contraseña del revisor: " PASSWORD; echo
curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: flutter-challenge-bi" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"<correo del revisor>\",\"password\":\"$PASSWORD\",\"emailVerified\":true}" \
  "https://identitytoolkit.googleapis.com/v1/projects/flutter-challenge-bi/accounts"
unset PASSWORD
```

Después se añade la dirección al secreto `backoffice-admin-emails` y se crea un despliegue nuevo para que el servidor lo lea. Las credenciales se entregan al revisor por un canal privado; nunca van en el repositorio. Esta orden no se ha ejecutado contra el proyecto real.

### Aplicación para el revisor

La aplicación debe compilarse apuntando al servidor publicado. Una compilación de publicación se niega a arrancar sin una dirección `https` para la API, y solo acepta un origen `https` para los aliados; las dos reglas tienen pruebas (`apps/mobile/test/api_base_url_test.dart`, `packages/feature_services/test/domain/partner_origin_test.dart`).

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<servidor>.hosted.app/ \
  --dart-define=PARTNER_BASE_URL=https://<servidor>.hosted.app \
  --dart-define=ALLOW_FAULT_INJECTION=true
```

`ALLOW_FAULT_INJECTION` solo tiene sentido en la demostración: permite que el laboratorio de resiliencia de la consola actúe sobre esta compilación. Firma: hoy la compilación de publicación usa la clave de depuración de la plantilla de Flutter, suficiente para instalar el APK a mano pero no para una tienda. Una firma propia necesita un almacén de claves fuera del repositorio y un `key.properties` ignorado por git; no está configurada.

### Reversión

- **Servidor:** en la consola de Firebase, App Hosting, elegir un despliegue anterior; o `firebase apphosting:rollouts:create backoffice --git-commit <commit>`.
- **Configuración publicada:** volver a publicar desde la consola de experiencia; cada publicación queda en la auditoría.
- **Retirar el servidor:** `firebase apphosting:backends:delete backoffice`. La aplicación del revisor deja de poder transferir y de abrir mini aplicaciones; las lecturas de Firestore siguen funcionando.

### Límites de costo y de abuso de una demostración pública

El registro de clientes es abierto y cada alta recibe dinero de demostración. Lo que cubre la configuración es el tope de instancias. El resto son ajustes de la consola de Firebase y de Google Cloud que debe aplicar la persona propietaria:

- [ ] Alerta de presupuesto en la cuenta de facturación.
- [ ] Cuota de altas por dirección IP en Authentication.
- [ ] Restricción de las claves de API de Android e iOS por aplicación, cuando ya no haga falta compilar desde el código con otra firma.
- [ ] App Check: trabajo futuro; hoy nada impide llamar a la API fuera de la aplicación con un token válido.
- [ ] Retirar el servidor al terminar la evaluación.

### En otro proveedor

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
