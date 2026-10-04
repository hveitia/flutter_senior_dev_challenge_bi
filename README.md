# Banca Digital

Plataforma financiera digital sin atención física: una aplicación móvil en Flutter cuya experiencia se compone a partir de configuración remota, y una consola web para cambiar esa experiencia sin publicar una nueva versión de la aplicación.

Este repositorio es la solución a la prueba técnica de Front-End Senior. Los datos son de demostración y no se ejecutan operaciones bancarias reales.

## Estado del proyecto

El proyecto se construye por etapas, con `main` siempre en verde. Esta sección se actualiza al cerrar cada etapa.

| Etapa | Alcance | Estado |
|---|---|---|
| 1. Cimientos | Monorepo, aplicación base, Firebase, CI, hook local, decisiones iniciales | Completa |
| 2. Sistema de diseño | Tokens, tema, componentes base y pruebas de accesibilidad | Completa |
| 3. Plataforma | Contrato de configuración, resiliencia, conectividad, observabilidad | Completa |
| 4. Acceso | Bienvenida, registro en tres pasos, inicio de sesión, desbloqueo biométrico y reglas del perfil | Completa |
| 5. Cuentas y movimientos | Navegación inferior, lectura en tiempo real, datos guardados sin conexión, filtros, búsqueda, paginación y estados degradados | Completa |
| 6. Inicio dinámico | Inicio armado desde la configuración publicada, registro de módulos por dominio, laboratorio de resiliencia y diagnóstico | Completa |
| 7. Consola web | Edición y publicación de configuración | Pendiente |
| 8. Transferencias | API de servidor, cola sin conexión y flujo E2E | Pendiente |
| 9. Notificaciones | Push y bandeja | Pendiente |
| 10. Servicios | Catálogo y micro aplicativos | Pendiente |
| 11. Cierre | Diagramas, despliegue, operación y guion de demostración | Pendiente |

Lo que existe hoy:

- **Acceso completo.** Un cliente nuevo abre su cuenta en tres pasos (datos con validación real de la cédula, intereses y segmento, contraseña), y uno existente inicia sesión, restablece su contraseña o desbloquea con huella o rostro una sesión restaurada. La aplicación enruta según el estado de la sesión.
- **Datos reales.** Las cuentas se crean en Firebase Authentication y el perfil se guarda en Firestore, en `users/{uid}`, bajo reglas de seguridad con pruebas automáticas.
- **Cuentas y movimientos.** Tras iniciar sesión hay cuatro secciones con navegación inferior. En Cuentas se ven el saldo total y cada cuenta; el detalle muestra saldo disponible y contable, el número con opción de copiarlo, y los movimientos agrupados por día, con filtros, búsqueda, paginación y una ficha por movimiento. Los datos se leen de Firestore en tiempo real y solo en lectura: el cliente no puede escribir saldos.
- **Inicio dirigido por configuración.** El inicio no tiene una composición fija: se arma en tiempo de ejecución con los módulos que la configuración publicada indica para el segmento del cliente, en el orden publicado. Al publicar otro orden u ocultar un módulo, la pantalla cambia sin reiniciar la aplicación. Cada dominio registra sus módulos y el inicio no conoce a ninguno ([ADR 0013](docs/adr/0013-registro-de-modulos-y-motor-del-inicio.md)). Un tipo de módulo que esta versión no conoce se omite.
- **Degradación.** Los formularios avisan de la falta de conexión, cada llamada pasa por la política de resiliencia y una cuenta cuyo perfil no llegó a guardarse se completa en el siguiente inicio de sesión. Sin conexión, el inicio, las cuentas y los movimientos se muestran desde la copia guardada en el dispositivo, indicando desde cuándo. Cada módulo del inicio tiene su propio estado: si los movimientos fallan, el saldo y las cuentas siguen en pantalla. El detalle está en [`docs/operacion/conectividad-degradada.md`](docs/operacion/conectividad-degradada.md).
- **Laboratorio de resiliencia.** La configuración publicada puede añadir latencia y dar por caído el servicio de movimientos. Solo tiene efecto en una compilación hecha para demostración; una compilación normal lo ignora.
- **Diagnóstico.** Perfil muestra el estado de la conexión, la antigüedad de la última sincronización, la versión y el origen de la configuración en uso y la versión de la aplicación, con valores reales.
- **Base.** El paquete `design_system` contiene los tokens, el tema y los componentes, con una galería para revisarlos. El paquete `app_platform` contiene la lectura de la configuración publicada, la política de resiliencia, el estado de conectividad y la observabilidad. El paquete `module_kit` es el contrato entre los dominios y el inicio.

Lo que todavía no hace la aplicación:

- La sección Servicios dice que está en construcción. Perfil muestra el nombre y el correo del cliente, el diagnóstico y permite cerrar sesión.
- Las acciones del inicio cuyo destino aún no tiene pantalla (transferir, recargar, el seguro de viaje) no se muestran, aunque la configuración las publique. Tampoco se dibujan los módulos de inversiones y de servicios recomendados, ni la línea de tendencia del saldo del segmento Patrimonio.
- No hay todavía consola web: la configuración se publica con una herramienta de desarrollo (ver [Publicar la configuración](#publicar-la-configuración-herramienta-de-desarrollo)).
- El segmento del cliente se elige al registrarse y la aplicación no ofrece cambiarlo después.
- Un cliente recién registrado no tiene cuentas hasta que exista la API de servidor que las abre. Mientras tanto hay una herramienta de desarrollo que carga datos de demostración (ver [Datos de demostración](#datos-de-demostración-herramienta-de-desarrollo)).
- No se puede transferir, compartir datos de la cuenta ni compartir un comprobante. Esas acciones del diseño no se muestran hasta que tengan algo detrás.

Qué se ha comprobado en ejecución:

- **En un emulador de Android** contra el proyecto real de Firebase (etapa 4): el registro, el cierre de sesión, el rechazo de una contraseña incorrecta, el inicio de sesión, la restauración de la sesión y el aviso sin conexión, y que el documento del perfil quedó creado.
- **En un teléfono Android real** contra el proyecto real (etapa 5): el inicio de sesión, la lista de cuentas, el detalle, los cuatro filtros, la búsqueda con y sin resultados, la ficha de un movimiento y la copia de su referencia, la paginación, los datos guardados en modo avión (también tras cerrar y abrir la aplicación sin conexión) y la recuperación al volver la conexión.
- **En un teléfono Android real** contra el proyecto real (etapa 6), con la compilación de demostración: el inicio armado desde la configuración publicada; un cambio de orden y un módulo oculto publicados mientras la aplicación estaba abierta, reflejados sin reiniciarla; el servicio de movimientos dado por caído, con el saldo y las cuentas en pantalla, y su recuperación; la latencia añadida y el aviso de conexión lenta; el inicio en modo avión y al abrir la aplicación sin conexión; el aviso de conexión restablecida; el diagnóstico con la versión publicada; y una compilación sin la opción de demostración, que ignoró los fallos publicados.
- **No se han comprobado en un dispositivo:** el desbloqueo biométrico, el correo de restablecimiento de contraseña, el inicio de un cliente de otro segmento, el error único cuando ningún módulo tiene datos (cubiertos por pruebas automáticas), ni nada en iOS.

La compilación de Android está verificada (`flutter build apk --debug`). El proyecto de iOS está configurado, pero su compilación aún no se ha verificado.

## Requisitos

- Flutter 3.38.3 (Dart 3.10.1). La versión está fijada en `.fvmrc`; con [FVM](https://fvm.app) basta ejecutar `fvm use`.
- Android SDK con un dispositivo o emulador (API 24 o superior), o Xcode para iOS.
- Git y Bash.
- Opcional: [Firebase CLI](https://firebase.google.com/docs/cli) para desplegar reglas o usar los emuladores.
- Opcional, para las pruebas de las reglas de Firestore: Node 22 o superior y Java 21 o superior.
- Opcional, para la herramienta de datos de demostración: Node 22 o superior y la [CLI de gcloud](https://cloud.google.com/sdk/docs/install) con una cuenta que tenga acceso al proyecto.

## Configuración

```bash
git clone https://github.com/hveitia/flutter_senior_dev_challenge_bi.git
cd flutter_senior_dev_challenge_bi
tool/setup.sh
```

`tool/setup.sh` activa los hooks de Git versionados en `.githooks/` y resuelve las dependencias de todo el workspace.

La aplicación apunta al proyecto de Firebase `flutter-challenge-bi`. Los archivos `firebase_options.dart`, `google-services.json` y `GoogleService-Info.plist` son identificadores de cliente, no secretos, y por eso están versionados. El acceso a los datos se protege con las reglas de `firebase/firestore.rules`.

## Ejecución

```bash
cd apps/mobile
flutter run
```

Para revisar el sistema de diseño (tokens y componentes en todos sus estados) sin iniciar Firebase ni ningún servicio:

```bash
cd apps/mobile
flutter run -t lib/main_gallery.dart
```

Para una demostración de degradación (latencia añadida y servicios caídos desde la configuración publicada), la compilación tiene que permitirlo de forma explícita:

```bash
cd apps/mobile
flutter run --dart-define=ALLOW_FAULT_INJECTION=true
```

Sin esa opción, la aplicación ignora el bloque `resilience` de la configuración: una compilación de producción no puede degradarse desde la consola ([ADR 0009](docs/adr/0009-politica-de-resiliencia.md)). Con ella, los fallos se aplican en cuanto se publican:

- **Latencia añadida.** Cada consulta al servidor espera el tiempo publicado. Al deslizar para actualizar, pasados tres segundos aparece el aviso «Conexión lenta. Seguimos intentando».
- **Movimientos no disponibles.** El módulo de últimos movimientos y el detalle de una cuenta dejan de recibir datos. Si ya había movimientos en pantalla, se conservan con un aviso; si la aplicación se abre con el servicio caído, el módulo muestra su error con «Reintentar» mientras el saldo y las cuentas siguen visibles. Al publicar de nuevo sin el fallo, «Reintentar» lo recupera.

Para instalar esa compilación en un teléfono sin depender del modo de depuración:

```bash
cd apps/mobile
flutter build apk --profile --dart-define=ALLOW_FAULT_INJECTION=true
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

La compilación de Android está verificada (`flutter build apk --debug`). El proyecto de iOS está configurado, pero su compilación aún no se ha verificado.

### Datos de demostración (herramienta de desarrollo)

Un cliente recién registrado todavía no tiene cuentas: las abrirá la API de servidor, que llega en una etapa posterior. Hasta entonces la aplicación le muestra «Estamos preparando tu cuenta». Para ver cuentas y movimientos reales hay una herramienta que carga dos cuentas y unos treinta movimientos a un cliente ya registrado:

```bash
cd firebase
node seed/seed.mjs --email correo-del-cliente@example.com --dry-run   # muestra lo que escribiría
node seed/seed.mjs --email correo-del-cliente@example.com             # lo escribe
```

- Escribe con las credenciales de Google de quien la ejecuta (`gcloud auth login`), que deben tener acceso al proyecto. No lee ni guarda ningún secreto en el repositorio.
- Solo escribe en `flutter-challenge-bi`; se niega a usar otro proyecto salvo que se le pase `--allow-other-project`.
- Muestra lo que va a escribir antes de hacerlo, y volver a ejecutarla reescribe los mismos documentos.
- Las fechas son relativas al día en que se ejecuta y los movimientos suman exactamente el saldo de cada cuenta.

Quien evalúe el proyecto no la necesitará cuando el registro abra las cuentas a través de la API.

### Publicar la configuración (herramienta de desarrollo)

La aplicación escucha el documento `config/home` de Firestore. Hasta que exista la consola web, se publica con una herramienta que escribe el ejemplo del contrato (`contracts/home-config.example.json`) u otro archivo con la misma forma:

```bash
cd firebase
node seed/publish-config.mjs --dry-run                       # muestra lo que publicaría
node seed/publish-config.mjs --bump                          # publica el ejemplo con la versión siguiente
node seed/publish-config.mjs --bump --latency-ms 5000        # añade 5 s de latencia
node seed/publish-config.mjs --bump --movements-unavailable  # da por caído el servicio de movimientos
node seed/publish-config.mjs --bump --from mi-config.json    # publica otro documento
```

- El documento se reemplaza entero: publicar sin las opciones de fallo los retira.
- `--bump` lee la versión publicada y publica la siguiente. La versión es informativa: la aplicación sigue siempre al último documento publicado.
- Usa las credenciales de Google de quien la ejecuta (`gcloud auth application-default login` o `gcloud auth login`), se niega a escribir en otro proyecto y muestra lo que va a publicar antes de hacerlo.
- Para cambiar el orden u ocultar un módulo, se copia el ejemplo, se edita la lista `modules` del segmento y se publica con `--from`. La pantalla de inicio cambia sin reiniciar la aplicación.

## Pruebas

```bash
tool/verify.sh
```

Ejecuta, en este orden, la comprobación de formato, el análisis estático y las pruebas de cada paquete del workspace. Es exactamente lo que ejecuta la integración continua en cada push.

El hook `pre-commit` usa el mismo script en modo acotado:

```bash
tool/verify.sh --affected
```

El formato y el análisis siguen cubriendo todo el repositorio. Las pruebas se limitan a los paquetes que el commit toca y a los que dependen de ellos, y el script imprime cuáles eligió y por qué.

Para ejecutar solo las pruebas de un paquete:

```bash
cd apps/mobile            # o cualquier carpeta de packages/
flutter test
```

Las reglas de seguridad de Firestore tienen sus propias pruebas, que se ejecutan contra el emulador. Necesitan Node 22 o superior y Java 21 o superior:

```bash
cd firebase
npm ci
npm test
```

No requieren credenciales: usan un proyecto de demostración que solo existe en el emulador. La integración continua las ejecuta en un trabajo aparte, junto con las pruebas de los datos de la herramienta de carga, que no necesitan emulador:

```bash
cd firebase
npm run test:seed
```

Qué cubren hoy las pruebas:

| Paquete | Qué se comprueba |
|---|---|
| `packages/design_system` | Deriva de los tokens respecto a `tokens/tokens.json`, contraste WCAG de cada combinación de color permitida, formato de importes, estados y semántica de cada componente, guías de accesibilidad de Flutter y ausencia de desbordamiento con texto al 130 % |
| `packages/app_platform` | Reglas de tolerancia del contrato de configuración, validación del ejemplo contra el esquema y diferencias entre ambos, repositorio de configuración (remota, guardada, incluida y de último recurso, con reconexión), política de resiliencia sobre un reloj simulado (reintentos solo para operaciones idempotentes, candado de la inyección de fallos), estados de conectividad, ausencia de datos del cliente en la telemetría, adaptadores y límite entre código puro y adaptadores |
| `packages/feature_auth` | Algoritmo de la cédula y demás validadores, repositorio de acceso (reintentos solo donde es seguro, cuenta a medio crear, errores tipados), Blocs de sesión, inicio de sesión y registro, pantallas con sus mensajes de error y guías de accesibilidad, redirección según la sesión, adaptadores y ausencia de datos personales en la telemetría |
| `packages/feature_accounts` | Filtro, búsqueda y agrupación por día de los movimientos, textos de fecha y de antigüedad con reloj inyectado, estado de un conjunto de datos (guardado, cargando, desactualizado), repositorio (origen y antigüedad de cada entrega, copia vacía que no se muestra, reintentos, movimientos caídos con cuentas en pie), Blocs de cuentas y de movimientos, pantallas en cada estado y con texto al 130 %, rutas, lectura tolerante de los documentos, ausencia de importes y números de cuenta en la telemetría, y límites entre capas |
| `packages/module_kit` | Registro de módulos (un dueño por tipo), lectura tolerante de las propiedades publicadas, aviso del estado de un módulo y registro de su actualización, aviso de conexión, y que el contrato no depende de ningún dominio, backend ni plugin |
| `packages/feature_home` | Composición del inicio (orden publicado, módulos ocultos, tipos desconocidos omitidos), recomposición al publicarse otra configuración o cambiar el segmento, aviso único de un tipo omitido, pantalla de inicio (módulos que conservan su estado, falla de un módulo frente a falla de todos, deslizar para actualizar, sin conexión, texto al 130 %), acciones rápidas y banner que solo muestran lo que la aplicación puede abrir, y que el paquete no depende de otro dominio |
| `apps/mobile` | Navegación según el estado de la sesión con dependencias simuladas, navegación inferior y secciones, repositorio de cuentas creado para el cliente que inicia sesión y liberado al cerrarla, inicio armado desde la configuración y recompuesto al publicar otra, configuración escuchada solo durante la sesión, fallos del laboratorio entregados a la política y retirados al cerrar sesión, resolución de destinos según pantallas existentes y funcionalidades activas, diagnóstico, pantalla de carga, galería del sistema de diseño, manejadores globales de errores, arranque sin telemetría cuando Firebase falla y validez de la configuración incluida |
| `firebase` | Reglas de seguridad: qué puede leer y escribir un cliente en su perfil, que puede leer y consultar sus cuentas y movimientos pero no los de otro, y que cuentas, movimientos y configuración no admiten escrituras de clientes. Datos de la herramienta de carga: saldos, sumas e identificadores estables. Documento que publica la herramienta de configuración: fallos pedidos, límites del contrato y conversión al formato de Firestore |

## Cómo colaborar

El repositorio sigue Trunk Based Development ([ADR 0006](docs/adr/0006-trunk-based-development.md)).

- Existe una única rama de larga vida: `main`. Siempre debe poder desplegarse.
- Los cambios son pequeños y frecuentes. Cada commit deja el workspace en verde.
- El hook `pre-commit` ejecuta `tool/verify.sh --affected` y bloquea el commit si algo falla. La verificación local se acota a lo que el commit puede romper:
  - Un cambio en un paquete ejecuta sus pruebas y las de todo paquete que dependa de él, directa o indirectamente.
  - Un cambio en la configuración común (`pubspec.yaml` y `pubspec.lock` de la raíz, `analysis_options.yaml`, `tool/`, `.githooks/`) ejecuta todo.
  - Un cambio en `contracts/` ejecuta el paquete de plataforma, que lee el contrato, y sus dependientes.
  - Un cambio en `firebase/` ejecuta las pruebas de reglas y de datos de carga si hay Java 21 o posterior; si no, lo avisa.
  - Un cambio solo en documentación no ejecuta pruebas.
- La puerta completa es la integración continua: ejecuta todas las pruebas en cada push a `main`. Lo que el hook deja sin ejecutar es lo que el commit no toca, y ya estaba en verde.
- El hook rechaza el commit cuando hay cambios sin preparar o archivos sin seguimiento en `apps/`, `packages/`, `contracts/`, `firebase/` o `tool/`. La verificación lee el directorio de trabajo, así que solo es válida si este coincide con lo que se confirma. No se puede preparar una parte de un archivo: lo que no entra en el commit se guarda antes con `git stash`.
- La integración continua repite la misma verificación en cada push a `main`.
- El trabajo incompleto se integra desactivado mediante configuración, no en ramas largas.
- Si `main` se rompe, repararlo o revertir el cambio es la prioridad.
- Los mensajes siguen [Conventional Commits](https://www.conventionalcommits.org) y se escriben en inglés.
- Las pruebas se escriben antes que el código que verifican.

En un equipo, el mismo flujo se mantiene con ramas de vida corta (menos de un día) integradas mediante pull request con la verificación en verde.

## Mapa del repositorio

```
apps/
  mobile/            Aplicación Flutter. Raíz de composición: rutas, inyección y tema.
packages/
  design_system/     Tokens, tema y componentes base. Referencia de diseño en tokens/tokens.json.
  app_platform/      Configuración publicada, resiliencia, conectividad y observabilidad.
  feature_auth/      Registro, inicio de sesión, sesión y desbloqueo biométrico.
  feature_accounts/  Cuentas, saldos y movimientos, solo lectura. Aporta al inicio los módulos de saldo, cuentas y últimos movimientos.
  module_kit/        Contrato entre los dominios y el inicio: registro de módulos, destinos y aviso de conexión.
  feature_home/      Motor del inicio: lo arma desde la configuración publicada. Aporta acciones rápidas y banner.
contracts/           Esquema y ejemplo de la configuración publicada. Fuente única para la aplicación y la consola.
firebase/            Reglas de seguridad e índices de Firestore, con las pruebas de las reglas.
  seed/              Herramientas de desarrollo: cargan cuentas y movimientos de demostración y publican la configuración.
docs/                Decisiones de arquitectura, diagramas, operación y registro de uso de IA.
tool/                Scripts de configuración y verificación.
.githooks/           Hooks de Git versionados.
.github/workflows/   Integración continua.
```

La carpeta `apps/backoffice` y los demás paquetes de `packages/` se crean en sus etapas correspondientes. La estructura completa prevista está en el [ADR 0001](docs/adr/0001-monorepo-workspaces-paquetes-por-dominio.md).

## Seguridad

- **Claves de Firebase en el repositorio.** `firebase_options.dart`, `google-services.json` y `GoogleService-Info.plist` contienen identificadores de cliente, no secretos. Ninguna clave de cuenta de servicio ni archivo `.env` se versiona.
- **Controles reales.** El acceso a los datos lo limitan las reglas de Firestore (`firebase/firestore.rules`), que niegan todo por defecto. Un cliente solo puede escribir su propio perfil, con una lista cerrada de campos validados; cuentas, saldos y movimientos no admiten escrituras de clientes. Las reglas tienen pruebas automáticas ([ADR 0011](docs/adr/0011-autenticacion-y-perfil.md)).
- **Datos personales.** La cédula, el nombre, el correo y el celular no se registran en la telemetría ni se guardan en el dispositivo.
- **Aplicado: restricción de claves por API.** Las claves solo pueden invocar los servicios de Firebase; no sirven para otras API de Google Cloud.
- **Pendiente: restricción de claves por aplicación.** La clave de Android debe restringirse por nombre de paquete y huella SHA-1, y la de iOS por identificador de paquete. No se aplica en este reto de forma deliberada: quien compile el proyecto desde el código firma con su propia clave de depuración y quedaría bloqueado.
- **Pendiente: App Check**, para aceptar solo peticiones de la aplicación legítima.
- **Pendiente: firma de publicación.** Aún no está configurada: la compilación de publicación usa la clave de depuración de la plantilla de Flutter. Se resolverá en la etapa de despliegue.

## Documentación

- [Índice de documentación](docs/README.md)
- [Decisiones de arquitectura](docs/adr/)
- [Registro de uso de IA](docs/ia/registro-uso-ia.md)
