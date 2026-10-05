# Guion de la demostración

Recorrido de unos 25 minutos, ordenado por lo que más pesa en la evaluación. Cada paso dice qué mostrar, qué decir en una frase y qué hacer si falla en vivo. Al final, los ejercicios que es probable que se pidan y dónde se toca cada uno.

Hay además un [video de demostración](https://youtu.be/ZUzv-hzOfw4) grabado: un recorrido narrado de la aplicación y la consola.

## Preparación (antes de la sesión)

Hay dos formas de prepararla. La primera es la que se comprobó de punta a punta en un teléfono. Quien evalúa parte del [sitio de entrega](https://flutter-challenge-bi.web.app), que reúne el video, la consola desplegada y el instalador de Android de la [versión v0.1.1](https://github.com/hveitia/flutter_senior_dev_challenge_bi/releases/tag/v0.1.1).

### Con la demostración desplegada

- Consola: <https://backoffice--flutter-challenge-bi.us-east4.hosted.app>, con una cuenta de administrador. Las credenciales se entregan por privado; no están en el repositorio.
- Aplicación: una compilación que apunta a ese servidor, con el comando de «Demostración publicada» del [README](../../README.md), instalada en un teléfono Android. Se entra con una cuenta de cliente de demostración, también entregada por privado, o registrando una nueva, que recibe sus cuentas al momento.
- Perfil > Diagnóstico muestra la versión de la configuración publicada: sirve para comprobar que el teléfono y la consola hablan con el mismo servidor.
- Tener abierto el repositorio en el editor y `tool/verify.sh` en verde.

Depende de la red del lugar. Las notificaciones son reales: un envío desde la consola llega al teléfono.

### En modo local

Sin depender de la red del lugar ni de credenciales. El servidor y los emuladores se comprobaron así desde una copia limpia del repositorio; la aplicación en este modo se compiló, pero no se ha ejecutado en un dispositivo, así que conviene ensayarlo antes:

```bash
tool/setup.sh
tool/local-stack.sh up        # emuladores de Auth y Firestore, servidor en el puerto 3210
tool/local-stack.sh seed      # configuración publicada, administrador y cliente locales

adb reverse tcp:9099 tcp:9099 # Auth
adb reverse tcp:8080 tcp:8080 # Firestore
adb reverse tcp:3210 tcp:3210 # consola, API y aliados

cd apps/mobile
flutter run --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=ALLOW_FAULT_INJECTION=true \
  --dart-define=PARTNER_BASE_URL=http://localhost:3210 \
  --dart-define=PARTNER_DEV_ORIGIN=true
```

- Consola: <http://localhost:3210>, con el administrador que imprime `seed`.
- Aplicación: el cliente que imprime `seed`. Perfil > Diagnóstico debe decir «Entorno: Emuladores locales».
- Tener abierto el repositorio en el editor y `tool/verify.sh` en verde.

En modo local las notificaciones no salen del equipo: el envío queda «Validado». Un push real solo se ve con la demostración desplegada ([operacion/backoffice.md](../operacion/backoffice.md)).

**Plan B general.** Si falla la red del lugar, pasar al modo local. Si el teléfono no coopera, un emulador de Android con los mismos comandos (los `adb reverse` también funcionan en él). Si tampoco, la galería del sistema de diseño (`flutter run -t lib/main_gallery.dart`) no necesita ningún servicio.

## Recorrido

| Min | Qué mostrar | Frase | Criterio | Si falla |
| --- | --- | --- | --- | --- |
| 0–2 | README: qué es, diagrama de componentes, tabla de estado por requisito | «Cada dominio es un paquete; se encuentran en un contrato y en la raíz de composición.» | Arquitectura, documentación | Abrir [arquitectura/componentes.md](../arquitectura/componentes.md) |
| 2–5 | Registro en tres pasos con una cédula inválida y después una válida; la cuenta nueva recibe sus dos cuentas | «El perfil lo escribe el cliente con reglas validadas; el dinero, solo el servidor.» | Experiencia, seguridad | Entrar con el cliente local ya creado |
| 5–9 | **Cambiar la experiencia sin publicar.** En la consola, mover «Saldo total» y publicar; el inicio del teléfono se redibuja. Perfil > Diagnóstico muestra la versión nueva | «El inicio es un documento publicado; la aplicación lo escucha y cada dominio aporta su módulo.» | Arquitectura, personalización | Publicar de nuevo; mostrar [arquitectura/publicar-configuracion.md](../arquitectura/publicar-configuracion.md) |
| 9–11 | Perfil > Personalización: cambiar a Patrimonio. Aparecen la tendencia de 30 días y las inversiones | «Mismos componentes, otra composición, y la tendencia se calcula con movimientos reales.» | Personalización | Mostrar el contrato en `contracts/home-config.example.json` |
| 11–15 | **Estados degradados.** En la consola, Laboratorio de resiliencia: latencia de 5 s (aviso de conexión lenta); «movimientos no disponibles» (ese módulo muestra su error, el saldo sigue); quitar los fallos y ver la recuperación. Después, modo avión con datos guardados y «Actualizado hace…» | «La falla parcial sale de la arquitectura: un Bloc por módulo.» | Pensamiento de producto, calidad | Modo avión no depende de la consola |
| 15–19 | **Transferencia.** Una normal y su movimiento. Saldo insuficiente. En modo avión queda «En cola»; al volver la conexión se liquida sola | «El identificador de la orden es la clave de idempotencia; una orden que pudo salir nunca se encola.» | Calidad, seguridad | Mostrar las pruebas de `default_transfers_repository_test.dart` |
| 19–21 | Servicios: cotizar el seguro de viaje. Dar por caído al aliado desde la consola con la mini aplicación abierta | «El origen del aliado se fija al compilar; la página solo conoce idioma y segmento.» | Integración externa | Abrir Recargas, que no depende de ese fallo |
| 21–22 | Bandeja: el aviso de la transferencia. Un envío desde la consola llega al teléfono con la demostración desplegada; en modo local queda «Validado» | «La bandeja la escribe el servidor; el push solo la anuncia.» | Notificaciones | Explicar con [arquitectura/flujos.md](../arquitectura/flujos.md) |
| 22–24 | `git log --oneline`, el hook y la CI en GitHub; el resumen de uso de IA | «Una rama, commits pequeños, la misma verificación en el hook y en la CI.» | Versionamiento, IA | — |
| 24–25 | [alcance-y-riesgos.md](../alcance-y-riesgos.md): lo que quedó fuera y por qué | «La publicación en tiendas, las notificaciones en iOS y la verificación de identidad quedaron fuera a propósito; está escrito.» | Pensamiento de producto | — |

## Ejercicios probables en vivo

Para cada uno: dónde se cambia, qué prueba lo cubre y con qué se comprueba.

### Añadir un tipo de módulo al inicio

1. Crear el widget en el paquete del dominio que lo posee.
2. Registrarlo con su tipo: `registerHomeModules` en `packages/feature_home/lib/src/modules/home_modules.dart`, o la función equivalente del dominio (`accounts_home_modules.dart`, la de servicios). El registro rechaza un tipo duplicado.
3. Si el módulo carga datos, envolverlo en `HomeModuleBinding` para que informe su estado (en espera, listo, fallido u oculto) y cómo refrescarse.
4. Publicarlo en un segmento desde la consola (o añadirlo a `contracts/home-config.example.json`).

Pruebas: `packages/module_kit/test/home_module_registry_test.dart` y las de composición de `packages/feature_home/test`. Una aplicación que no conozca el tipo lo omite: no hay que coordinar la publicación.

### Añadir un token de diseño

1. Añadirlo en `packages/design_system/tokens/tokens.json`.
2. Añadirlo en la clase de tokens (`packages/design_system/lib/src/tokens/`).
3. `flutter test test/tokens/token_drift_test.dart` en el paquete: falla si falta en uno de los dos lados o si el valor difiere.

Si es un color de texto, añadir la pareja a las pruebas de contraste: fallarán si no alcanza 4.5:1.

### Cambiar el límite de una transferencia

Vive en tres sitios, a propósito, porque son tres barreras:

1. Aplicación: `TransferLimits.maxCents` en `packages/feature_accounts/lib/src/domain/transfer.dart` (prueba: `test/domain/transfer_test.dart`).
2. Servidor: `MAX_TRANSFER_CENTS` en `apps/backoffice/lib/api/transfer.ts` (prueba: `transfer.test.ts`).
3. Reglas: `transfer.amountCents <= 500000` en `firebase/firestore.rules` (prueba: «one cent over the limit» en `firebase/test/firestore.rules.test.js`).

Si solo se sube el de la aplicación, el servidor rechaza con un motivo y la pantalla lo muestra: es un buen caso para enseñar que el servidor es la autoridad.

### Añadir un destino

1. Nombrarlo en `Destinations` (`packages/module_kit/lib/src/destination_resolver.dart`).
2. Darle una ruta en `apps/mobile/lib/destinations.dart`, detrás de su interruptor si lo tiene.
3. Añadirlo a `destinations` en el contrato y en la configuración publicada.

Prueba: `apps/mobile/test/destinations_test.dart`. Sin el paso 2, cualquier acción que lo use se oculta y una notificación que lo nombre abre la bandeja.

### Diagnosticar una configuración rechazada

- Síntoma: se publicó y el teléfono no cambia. Perfil > Diagnóstico sigue en la versión anterior o dice «guardada».
- Señal: evento `config_rejected` con el motivo.
- Causas: `schemaVersion` mayor que la que la aplicación entiende, raíz que no es un objeto, ningún segmento utilizable, propiedades anidadas a más de 32 niveles.
- Dónde mirar: `packages/app_platform/lib/src/config/home_config_parser.dart` y sus pruebas, que tienen un caso por motivo.
- Por qué no rompe nada: el repositorio conserva la última configuración válida.

### Diagnosticar una transferencia en cola que no se liquida

- ¿Llegó la orden al servidor? Buscar `users/{uid}/transfers/{id}` en Firestore (o en la interfaz del emulador, <http://localhost:4000>). Si no está, sigue en la cola local: no hay conexión, o las reglas la rechazaron y el cliente ve el aviso de «no se pudo enviar».
- ¿Está en estado `pending`? Entonces falta que alguien pida procesarla: el procesador de salida lo hace al recuperar la conexión y al arrancar (`packages/feature_accounts/lib/src/presentation/transfer/transfer_outbox_cubit.dart`). Mirar el registro del servidor por la ruta `transfers.process`.
- ¿La API responde? `curl -X POST http://localhost:3210/api/accounts/provision` debe dar 401 sin token; si no responde, el problema es el servidor o el `adb reverse`.
- ¿Está `rejected`? El documento lleva el motivo, y la aplicación lo muestra.
- Procesar a mano es seguro: `POST /api/transfers/{id}/process` es idempotente.

### Ajustar una prueba

Las pruebas nombran comportamiento, no implementación, así que el cambio suele ser el dato esperado. Dos buenos ejemplos para hacerlo en vivo:

- Cambiar el texto de un estado (por ejemplo el aviso sin conexión) y ver qué prueba de pantalla falla.
- Cambiar el número de reintentos de la política de resiliencia (`packages/app_platform`): las pruebas usan un reloj simulado y fallan de inmediato, sin esperas reales.
