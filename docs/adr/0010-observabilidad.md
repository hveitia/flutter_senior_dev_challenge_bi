# 0010. Observabilidad detrás de una interfaz, sin datos del cliente en los registros

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existen en `packages/app_platform` la interfaz `Telemetry`, el adaptador de Firebase (Crashlytics, Analytics y Performance), el doble en memoria para pruebas y el `AppBlocObserver`. La aplicación instala el observador y los manejadores globales de errores al arrancar. La compilación de Android con el plugin de Crashlytics está verificada. **No se ha comprobado que los informes lleguen a la consola de Firebase**, porque la aplicación no se ha ejecutado en un dispositivo en esta etapa. Las trazas y los eventos de cada funcionalidad se añaden en sus etapas.

## Problema a resolver

El enunciado pide explicar cómo se monitorea la aplicación en producción y cómo se detectan problemas operativos o de experiencia. Hay dos riesgos al resolverlo:

- Que el código de dominio dependa directamente del SDK de un proveedor, lo que impide probarlo y cambiarlo.
- Que los registros contengan datos del cliente. En una aplicación bancaria, los estados y los errores llevan saldos, números de cuenta y nombres.

## Alternativas evaluadas

**Acceso a la telemetría**

1. **Una interfaz propia y pequeña, con un adaptador por proveedor.**
2. **Llamar a los SDK de Firebase desde donde haga falta.** Menos código; cada paquete de dominio queda atado a Firebase y sus pruebas necesitan simularlo.
3. **Un paquete genérico de registro.** Resuelve los registros, no los errores, las trazas ni los eventos.

**Qué informa el observador de Bloc**

1. **Solo tipos: el del Bloc, el del estado y el del error, más la traza de la pila.**
2. **El estado y el error completos.** Más fácil de depurar; envía datos del cliente a un tercero.
3. **Estados completos pasados por un filtro de campos sensibles.** Depende de que cada estado nuevo se declare bien; un olvido es una fuga.

**Proveedor**

1. **Crashlytics, Analytics y Performance de Firebase.** Ya forman parte del backend elegido ([ADR 0002](0002-firebase-como-backend.md)).
2. **Sentry u otro servicio dedicado.** Mejor seguimiento de errores entre aplicación y servidor; añade un proveedor y una cuenta.

## Opción seleccionada

La primera opción en los tres casos.

**Interfaz** (`Telemetry`): registros con nivel y contexto, informe de errores, eventos de producto, trazas con atributos y contexto global.

**Qué se envía a cada servicio**

| Llamada | Destino |
|---|---|
| Registros desde el nivel `info` | Rastro de Crashlytics, visible junto a un fallo |
| Registros de nivel `debug` | Solo consola de desarrollo |
| Errores | Crashlytics, con motivo y gravedad |
| Contexto (por ejemplo, la versión de configuración) | Clave personalizada de Crashlytics, presente en cada informe |
| Eventos | Analytics |
| Trazas | Performance |

El envío es de mejor esfuerzo: un fallo del servicio de telemetría nunca alcanza a la funcionalidad que informa.

**Qué no se registra**

- **El contenido de los estados.** El observador informa `_BalanceState`, no el saldo. Si el estado es un enumerado, informa también su valor, que no contiene datos.
- **El mensaje de los errores de un Bloc.** Se sustituye por `RedactedError(Tipo)`. La traza de la pila se conserva.
- **Datos personales o financieros en eventos y contexto.** La interfaz lo exige en su documentación; se usan identificadores que define la aplicación (tipo de módulo, clase de fallo).

Dos pruebas lo sostienen: recorren todo lo que el observador entregó a la telemetría y fallan si aparece el importe, el número de cuenta o el nombre de un estado o de un error de ejemplo. Se comprobó que fallan alterando temporalmente el observador para que registrara el estado y el error completos.

**Errores globales.** `installTelemetry` conecta los errores del framework y los errores asíncronos no capturados con la telemetría, marcados como graves.

**Dependencias añadidas:** `firebase_crashlytics`, `firebase_analytics`, `firebase_performance` y el plugin de Gradle de Crashlytics, que el SDK necesita para arrancar en Android. El plugin de Gradle de Performance no se añade: solo aporta la medición automática de red, y las trazas propias funcionan sin él.

## Trade-offs

- **Se gana:** los paquetes de dominio se prueban con un doble en memoria y pueden afirmar qué se informó.
- **Se gana:** la regla de privacidad del observador no depende de la disciplina de quien escribe un estado nuevo.
- **Se paga:** depurar un fallo de un Bloc es más difícil sin el mensaje del error. Quedan el tipo, la pila y el rastro de registros.
- **Se paga:** la protección cubre lo que pasa por el observador. Los errores del framework y los asíncronos no capturados se informan completos, porque sin su mensaje no pueden diagnosticarse; si uno incluyera datos del cliente en su mensaje, se enviarían.
- **Se paga:** nada impide en compilación que una funcionalidad pase un dato sensible a `event` o a `log`. Es una convención documentada y un punto de revisión.
- **Se paga:** con ofuscación de código, los nombres de tipos que informa el observador quedan ofuscados y hay que traducirlos con los símbolos de la compilación.
- **Se paga:** no hay correlación entre un fallo de la aplicación y los registros del servidor.

## Impacto a largo plazo

Cambiar o añadir un proveedor es escribir otro adaptador. La estrategia de monitoreo que se apoya en esta base está en [`docs/operacion/monitoreo.md`](../operacion/monitoreo.md). Convendría revisar la decisión al necesitar trazabilidad de extremo a extremo entre aplicación y servidor, o un consentimiento del usuario que condicione la analítica.
