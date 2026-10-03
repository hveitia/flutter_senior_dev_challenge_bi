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
| 5. Cuentas y movimientos | Lectura en tiempo real, caché y estados | Pendiente |
| 6. Inicio dinámico | Motor de módulos por segmento y estados degradados | Pendiente |
| 7. Consola web | Edición y publicación de configuración | Pendiente |
| 8. Transferencias | API de servidor, cola sin conexión y flujo E2E | Pendiente |
| 9. Notificaciones | Push y bandeja | Pendiente |
| 10. Servicios | Catálogo y micro aplicativos | Pendiente |
| 11. Cierre | Diagramas, despliegue, operación y guion de demostración | Pendiente |

Lo que existe hoy:

- **Acceso completo.** Un cliente nuevo abre su cuenta en tres pasos (datos con validación real de la cédula, intereses y segmento, contraseña), y uno existente inicia sesión, restablece su contraseña o desbloquea con huella o rostro una sesión restaurada. La aplicación enruta según el estado de la sesión.
- **Datos reales.** Las cuentas se crean en Firebase Authentication y el perfil se guarda en Firestore, en `users/{uid}`, bajo reglas de seguridad con pruebas automáticas.
- **Degradación.** Los formularios avisan de la falta de conexión, cada llamada pasa por la política de resiliencia y una cuenta cuyo perfil no llegó a guardarse se completa en el siguiente inicio de sesión.
- **Base.** El paquete `design_system` contiene los tokens, el tema y los componentes, con una galería para revisarlos. El paquete `app_platform` contiene la lectura de la configuración publicada, la política de resiliencia, el estado de conectividad y la observabilidad.

Lo que todavía no hace la aplicación: tras iniciar sesión muestra una pantalla provisional con el nombre del cliente y la opción de cerrar sesión. Las cuentas, los movimientos y el inicio dinámico llegan en las etapas 5 y 6, que es también cuando se empieza a escuchar la configuración publicada.

Qué se ha comprobado en ejecución: el registro, el cierre de sesión, el rechazo de una contraseña incorrecta, el inicio de sesión, la restauración de la sesión y el aviso sin conexión se recorrieron en un emulador de Android contra el proyecto real de Firebase, y se comprobó que el documento del perfil quedó creado. No se han comprobado en un dispositivo el desbloqueo biométrico ni el correo de restablecimiento de contraseña.

La compilación de Android está verificada (`flutter build apk --debug`). El proyecto de iOS está configurado, pero su compilación aún no se ha verificado.

## Requisitos

- Flutter 3.38.3 (Dart 3.10.1). La versión está fijada en `.fvmrc`; con [FVM](https://fvm.app) basta ejecutar `fvm use`.
- Android SDK con un dispositivo o emulador (API 24 o superior), o Xcode para iOS.
- Git y Bash.
- Opcional: [Firebase CLI](https://firebase.google.com/docs/cli) para desplegar reglas o usar los emuladores.
- Opcional, para las pruebas de las reglas de Firestore: Node 22 o superior y Java 21 o superior.

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

Sin esa opción, la aplicación ignora el bloque `resilience` de la configuración: una compilación de producción no puede degradarse desde la consola. La política de resiliencia ya recibe la opción, pero todavía no tiene efecto visible: los fallos llegan con la configuración publicada, que la aplicación empieza a escuchar en la etapa 6 ([ADR 0009](docs/adr/0009-politica-de-resiliencia.md)).

La compilación de Android está verificada (`flutter build apk --debug`). El proyecto de iOS está configurado, pero su compilación aún no se ha verificado.

## Pruebas

```bash
tool/verify.sh
```

Ejecuta, en este orden, la comprobación de formato, el análisis estático y las pruebas de cada paquete del workspace. Es exactamente lo mismo que ejecutan el hook `pre-commit` y la integración continua.

Para ejecutar solo las pruebas de un paquete:

```bash
cd apps/mobile            # o packages/design_system, packages/app_platform, packages/feature_auth
flutter test
```

Las reglas de seguridad de Firestore tienen sus propias pruebas, que se ejecutan contra el emulador. Necesitan Node 22 o superior y Java 21 o superior:

```bash
cd firebase
npm ci
npm test
```

No requieren credenciales: usan un proyecto de demostración que solo existe en el emulador. La integración continua las ejecuta en un trabajo aparte.

Qué cubren hoy las pruebas:

| Paquete | Qué se comprueba |
|---|---|
| `packages/design_system` | Deriva de los tokens respecto a `tokens/tokens.json`, contraste WCAG de cada combinación de color permitida, formato de importes, estados y semántica de cada componente, guías de accesibilidad de Flutter y ausencia de desbordamiento con texto al 130 % |
| `packages/app_platform` | Reglas de tolerancia del contrato de configuración, validación del ejemplo contra el esquema y diferencias entre ambos, repositorio de configuración (remota, guardada, incluida y de último recurso, con reconexión), política de resiliencia sobre un reloj simulado (reintentos solo para operaciones idempotentes, candado de la inyección de fallos), estados de conectividad, ausencia de datos del cliente en la telemetría, adaptadores y límite entre código puro y adaptadores |
| `packages/feature_auth` | Algoritmo de la cédula y demás validadores, repositorio de acceso (reintentos solo donde es seguro, cuenta a medio crear, errores tipados), Blocs de sesión, inicio de sesión y registro, pantallas con sus mensajes de error y guías de accesibilidad, redirección según la sesión, adaptadores y ausencia de datos personales en la telemetría |
| `apps/mobile` | Navegación según el estado de la sesión con dependencias simuladas, pantalla de carga, galería del sistema de diseño, manejadores globales de errores, arranque sin telemetría cuando Firebase falla y validez de la configuración incluida |
| `firebase` | Reglas de seguridad: qué puede leer y escribir un cliente en su perfil, y que cuentas, movimientos y configuración no admiten escrituras de clientes |

## Cómo colaborar

El repositorio sigue Trunk Based Development ([ADR 0006](docs/adr/0006-trunk-based-development.md)).

- Existe una única rama de larga vida: `main`. Siempre debe poder desplegarse.
- Los cambios son pequeños y frecuentes. Cada commit deja el workspace en verde.
- El hook `pre-commit` ejecuta `tool/verify.sh` y bloquea el commit si algo falla.
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
contracts/           Esquema y ejemplo de la configuración publicada. Fuente única para la aplicación y la consola.
firebase/            Reglas de seguridad e índices de Firestore, con las pruebas de las reglas.
docs/                Decisiones de arquitectura, operación y registro de uso de IA.
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
