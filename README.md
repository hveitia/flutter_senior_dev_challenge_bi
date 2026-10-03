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
| 4. Acceso | Bienvenida, registro y autenticación | Pendiente |
| 5. Cuentas y movimientos | Lectura en tiempo real, caché y estados | Pendiente |
| 6. Inicio dinámico | Motor de módulos por segmento y estados degradados | Pendiente |
| 7. Consola web | Edición y publicación de configuración | Pendiente |
| 8. Transferencias | API de servidor, cola sin conexión y flujo E2E | Pendiente |
| 9. Notificaciones | Push y bandeja | Pendiente |
| 10. Servicios | Catálogo y micro aplicativos | Pendiente |
| 11. Cierre | Diagramas, despliegue, operación y guion de demostración | Pendiente |

Lo que existe hoy: la aplicación arranca, inicializa Firebase, instala la telemetría y muestra la marca del producto con el tema del sistema de diseño. El paquete `design_system` contiene los tokens, el tema y los componentes base, y una galería permite revisarlos en un dispositivo. El paquete `app_platform` contiene la lectura de la configuración publicada, la política de resiliencia, el estado de conectividad y la observabilidad.

Lo que todavía no hace la aplicación: de `app_platform` solo usa la telemetría. La configuración, la resiliencia y la conectividad están probadas de forma aislada y se conectan a las pantallas en las etapas 5 y 6. Nada de esta etapa se ha ejecutado contra el Firestore real ni en un dispositivo.

La compilación de Android está verificada (`flutter build apk --debug`). El proyecto de iOS está configurado, pero su compilación aún no se ha verificado.

## Requisitos

- Flutter 3.38.3 (Dart 3.10.1). La versión está fijada en `.fvmrc`; con [FVM](https://fvm.app) basta ejecutar `fvm use`.
- Android SDK con un dispositivo o emulador (API 24 o superior), o Xcode para iOS.
- Git y Bash.
- Opcional: [Firebase CLI](https://firebase.google.com/docs/cli) para desplegar reglas o usar los emuladores.

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

La compilación de Android está verificada (`flutter build apk --debug`). El proyecto de iOS está configurado, pero su compilación aún no se ha verificado.

## Pruebas

```bash
tool/verify.sh
```

Ejecuta, en este orden, la comprobación de formato, el análisis estático y las pruebas de cada paquete del workspace. Es exactamente lo mismo que ejecutan el hook `pre-commit` y la integración continua.

Para ejecutar solo las pruebas de un paquete:

```bash
cd apps/mobile            # o packages/design_system, packages/app_platform
flutter test
```

Qué cubren hoy las pruebas:

| Paquete | Qué se comprueba |
|---|---|
| `packages/design_system` | Deriva de los tokens respecto a `tokens/tokens.json`, contraste WCAG de cada combinación de color permitida, formato de importes, estados y semántica de cada componente, guías de accesibilidad de Flutter y ausencia de desbordamiento con texto al 130 % |
| `packages/app_platform` | Reglas de tolerancia del contrato de configuración, repositorio de configuración (remota, guardada e incluida), política de resiliencia sobre un reloj simulado, estados de conectividad, ausencia de datos del cliente en la telemetría, adaptadores y límite entre código puro y adaptadores |
| `apps/mobile` | Pantalla de inicio de carga con el tema aplicado, galería del sistema de diseño, manejadores globales de errores y validez de la configuración incluida |

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
contracts/           Esquema y ejemplo de la configuración publicada. Fuente única para la aplicación y la consola.
firebase/            Reglas de seguridad e índices de Firestore.
docs/                Decisiones de arquitectura, operación y registro de uso de IA.
tool/                Scripts de configuración y verificación.
.githooks/           Hooks de Git versionados.
.github/workflows/   Integración continua.
```

La carpeta `apps/backoffice` y los demás paquetes de `packages/` se crean en sus etapas correspondientes. La estructura completa prevista está en el [ADR 0001](docs/adr/0001-monorepo-workspaces-paquetes-por-dominio.md).

## Seguridad

- **Claves de Firebase en el repositorio.** `firebase_options.dart`, `google-services.json` y `GoogleService-Info.plist` contienen identificadores de cliente, no secretos. Ninguna clave de cuenta de servicio ni archivo `.env` se versiona.
- **Controles reales.** El acceso a los datos lo limitan las reglas de Firestore (`firebase/firestore.rules`), que niegan todo por defecto.
- **Aplicado: restricción de claves por API.** Las claves solo pueden invocar los servicios de Firebase; no sirven para otras API de Google Cloud.
- **Pendiente: restricción de claves por aplicación.** La clave de Android debe restringirse por nombre de paquete y huella SHA-1, y la de iOS por identificador de paquete. No se aplica en este reto de forma deliberada: quien compile el proyecto desde el código firma con su propia clave de depuración y quedaría bloqueado.
- **Pendiente: App Check**, para aceptar solo peticiones de la aplicación legítima.
- **Pendiente: firma de publicación.** Aún no está configurada: la compilación de publicación usa la clave de depuración de la plantilla de Flutter. Se resolverá en la etapa de despliegue.

## Documentación

- [Índice de documentación](docs/README.md)
- [Decisiones de arquitectura](docs/adr/)
- [Registro de uso de IA](docs/ia/registro-uso-ia.md)
