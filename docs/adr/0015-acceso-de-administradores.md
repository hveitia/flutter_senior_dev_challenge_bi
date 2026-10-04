# 0015. Acceso de administradores y credenciales del servidor de la consola

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existen en `apps/backoffice` el intercambio del token de identidad por una cookie de sesión, la lista de administradores, la comprobación de origen y la guarda de proyecto, con pruebas de los caminos denegados. Se comprobó en local contra el proyecto real con una cuenta de administrador de prueba. El servidor está desplegado en Firebase App Hosting con la identidad de servicio de la plataforma; el uso de una cuenta de servicio por variable de entorno está implementado pero no se ha ejecutado. En el servidor publicado se comprobaron los caminos denegados y la comprobación de origen; el inicio de sesión de un administrador solo puede comprobarlo quien tiene la cuenta.

## Problema a resolver

La consola publica la configuración que ven todos los clientes y envía notificaciones a sus teléfonos. Su servidor actúa con privilegios de administrador, que saltan las reglas de Firestore. Si alguien no autorizado llega a una de sus operaciones, las reglas no lo detienen.

Hay dos preguntas distintas: quién puede usar la consola, y con qué credenciales actúa el servidor sin que esas credenciales acaben en un repositorio público.

Un detalle del proyecto agrava la primera: el registro en la aplicación móvil es abierto ([ADR 0011](0011-autenticacion-y-perfil.md)). Cualquiera puede crear una cuenta con cualquier dirección que aún no esté registrada, incluida la de un administrador.

## Alternativas evaluadas

**Cómo se mantiene la sesión**

1. **Cookie de sesión emitida por el servidor, solo HTTP, a partir de un token de identidad reciente.** El navegador no guarda nada que un script pueda leer.
2. **Enviar el token de identidad en cada petición desde el navegador.** Sin estado en el servidor; el token vive en memoria o almacenamiento del navegador, al alcance de cualquier script inyectado.
3. **Autenticación básica delante de la aplicación.** Trivial de montar; una sola contraseña compartida y sin saber quién publicó.

**Quién es administrador**

1. **Lista de direcciones en la configuración del servidor, más dirección verificada.** Nada que administrar fuera del despliegue.
2. **Atributo personalizado (`admin`) en la cuenta.** Es lo correcto a escala; exige una herramienta para concederlo y revocarlo.
3. **Cualquier cuenta que inicie sesión.** Con registro abierto, equivale a no tener control.

**Con qué credenciales actúa el servidor**

1. **Credenciales por defecto de la máquina en desarrollo; cuenta de servicio por variable de entorno en el despliegue.** Ningún archivo de clave en el repositorio.
2. **Archivo de clave de cuenta de servicio en el repositorio, ignorado por git.** Un descuido lo publica; en un repositorio público no es aceptable.
3. **Identidad federada del proveedor de despliegue (sin clave).** Es la opción a la que apuntar; depende de dónde se despliegue.

## Opción seleccionada

La primera opción en los tres casos.

**Sesión** (`lib/server/session.ts`, `app/api/session/route.ts`):

| Aspecto | Valor |
|---|---|
| Inicio de sesión | Correo y contraseña contra el proveedor de identidad, en el navegador, con persistencia en memoria y cierre inmediato |
| Intercambio | El token se envía una vez a `POST /api/session`; debe ser de un inicio de sesión de los últimos 5 minutos y no estar revocado |
| Cookie | `__session`, solo HTTP, `SameSite=Strict`, `Secure` en producción, 8 horas |
| Verificación | En cada petición, con comprobación de revocación, y la lista de administradores se vuelve a consultar |
| Cierre | `DELETE /api/session` verifica la cookie, revoca las sesiones del administrador en el proveedor de identidad y borra la cookie de ese navegador |

**Admisión.** Solo se admite una dirección que esté en `ADMIN_EMAILS` **y** esté verificada. La segunda condición es la que cierra el hueco del registro abierto: quien registre la dirección de un administrador desde la aplicación obtiene una cuenta sin verificar, que la consola rechaza. Quitar una dirección de la lista surte efecto en la siguiente petición de esa persona, no al caducar su cookie.

**Una sola respuesta para cada rechazo.** Un token inventado, una contraseña incorrecta, una dirección que no es de administrador y una dirección sin verificar reciben la misma respuesta, sin motivo. Desde fuera no se puede averiguar qué direcciones son de administrador.

**Cada operación se protege a sí misma.** La página, la acción de publicar y la ruta de notificaciones llaman a la comprobación de sesión por su cuenta. No hay una capa exterior en cuya comprobación confíe el código interior.

**Peticiones entre sitios.** La cookie es `SameSite=Strict`. La publicación es una acción de servidor, a la que el framework compara el origen con el host. Las rutas `/api/session` y `/api/push` hacen la misma comparación con `lib/server/same-origin.ts`, y rechazan además una petición sin cabecera de origen.

**Credenciales** (`lib/server/firebase.ts`, `lib/server/settings.ts`). Si existe `FIREBASE_SERVICE_ACCOUNT`, se usa; si no, las credenciales por defecto: las de la máquina en desarrollo (`gcloud auth application-default login`) y la identidad de servicio de la plataforma en el despliegue. El alojamiento elegido, Firebase App Hosting, corre dentro del mismo proyecto, así que en él no existe ninguna clave de cuenta de servicio; esa fue la razón para preferirlo a un proveedor externo, a cambio de exigir el plan de pago por uso. En el despliegue, esa identidad verificó tokens y leyó y escribió en Firestore sin que hubiera que concederle ningún permiso: sus funciones por defecto (`firebase.sdkAdminServiceAgent`, `firebaseapphosting.computeRunner`) incluyen también crear sesiones, actualizar usuarios y enviar mensajes, que no se han ejercitado todavía en el servidor publicado. El servidor se niega a arrancar contra un proyecto distinto de `flutter-challenge-bi` salvo que `ALLOW_OTHER_PROJECT=true` lo permita, y sin al menos un administrador en la lista. Un valor de cuenta de servicio mal formado se rechaza sin incluirlo en el mensaje de error. El JSON de la cuenta de servicio solo debe existir en el almacén de secretos del proveedor de despliegue: nunca en el repositorio, en un archivo de entorno compartido ni en el historial de un terminal.

## Trade-offs

- **Se gana:** la sesión no es legible desde JavaScript y no viaja en peticiones iniciadas por otros sitios.
- **Se gana:** el registro abierto de la aplicación no da acceso a la consola.
- **Se gana:** ninguna clave en el repositorio ni en la máquina de quien desarrolla.
- **Se paga:** la lista de administradores vive en la configuración del despliegue; cambiarla es cambiar una variable y reiniciar, y no queda registro de ese cambio.
- **Se paga:** dos verificaciones contra el proveedor de identidad por petición autenticada (cookie y revocación), a cambio de que una revocación tenga efecto inmediato.
- **Se gana:** cerrar sesión invalida también una cookie copiada antes del cierre, porque cada petición comprueba la revocación. Se comprobó contra el proyecto real: la cookie que daba acceso dejó de darlo tras el cierre.
- **Se paga:** la revocación es por cuenta, no por navegador. Cerrar sesión en un equipo cierra la del mismo administrador en todos los demás. Para una herramienta interna de pocos usuarios se prefirió eso a dejar sesiones vivas.
- **Límite:** si la revocación falla (el proveedor no responde), la cookie se borra igualmente en ese navegador y la respuesta lo indica, pero una copia seguiría valiendo hasta caducar.
- **Límite:** no hay segundo factor.
- **Límite:** no hay límite de frecuencia propio. Los intentos de inicio de sesión solo tienen el que aplica el proveedor de identidad; los envíos de notificaciones y las búsquedas de cliente por correo que hace un administrador autenticado no tienen ninguno. Un administrador podría probar direcciones enviando notificaciones: los fallos no distinguen entre «no es cliente» y «cliente sin dispositivo» ([ADR 0014](0014-consola-de-experiencia.md)), pero un envío logrado sí confirma que la dirección es de un cliente. Cada envío queda registrado con quién lo hizo.
- **Límite:** las cuentas de administrador se crean a mano con la herramienta de administración, marcadas como verificadas. No hay un flujo de alta.
- **Límite:** las credenciales por defecto de desarrollo son las de una persona con permisos amplios sobre el proyecto, más de los que la consola necesita.

## Impacto a largo plazo

En producción la lista pasaría a un atributo en la cuenta, concedido por un proceso auditado, y el inicio de sesión al proveedor de identidad corporativo con segundo factor. El punto de cambio es uno: la función que decide la admisión en `lib/server/session.ts`.

La cuenta de servicio del despliegue debería tener solo los permisos que la consola usa (Firestore, autenticación y mensajería del proyecto), y sustituirse por identidad federada donde el proveedor lo permita, para que no exista una clave que rotar.

Si la consola deja de ser de una pantalla y aparecen roles (quien edita, quien publica, quien envía notificaciones), la admisión devolvería el rol junto a la identidad y cada operación comprobaría el suyo; el resto del diseño no cambia.
