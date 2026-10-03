# 0011. Autenticación con Firebase Auth y perfil escrito por el cliente bajo reglas

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existe el paquete `packages/feature_auth` con el registro en tres pasos, el inicio de sesión, el restablecimiento de contraseña, el desbloqueo biométrico, la recuperación de cuentas a medio crear y sus pantallas. La aplicación enruta según la sesión. Las reglas de Firestore que admiten la escritura del perfil están desplegadas y tienen pruebas automáticas contra el emulador. **Verificado en un emulador de Android contra el proyecto real de Firebase:** registro completo, creación del documento `users/{uid}`, cierre de sesión, rechazo de una contraseña incorrecta, inicio de sesión, restauración de la sesión tras reiniciar la aplicación y aviso de falta de conexión. **No verificado:** el desbloqueo biométrico en un dispositivo (el emulador no tiene biometría registrada), el correo de restablecimiento de contraseña, la recuperación de una cuenta a medio crear contra el backend real, y nada en iOS.

## Problema a resolver

El enunciado pide onboarding y autenticación de clientes en una plataforma sin atención física. Hay que decidir:

- Quién guarda las credenciales y quién guarda los datos del cliente.
- Qué puede escribir la aplicación directamente y qué queda reservado al servidor.
- Qué ocurre cuando el alta se interrumpe a la mitad, con la cuenta creada y el perfil sin guardar.
- Cuánto revelan los mensajes de error sobre qué correos están registrados.
- Qué papel tiene la biometría.
- Cuándo empieza la aplicación a escuchar la configuración publicada, que solo pueden leer usuarios autenticados.

## Alternativas evaluadas

**Credenciales**

1. **Firebase Authentication con correo y contraseña.** Forma parte del backend elegido ([ADR 0002](0002-firebase-como-backend.md)). La aplicación nunca almacena la contraseña.
2. **Autenticación propia en la API de servidor.** Control total; obliga a construir y proteger el almacenamiento de credenciales, la recuperación y la limitación de intentos.
3. **Sin contraseña (enlace por correo o código por SMS).** Mejor experiencia; depende de la entrega del mensaje y, en SMS, tiene costo y requiere el plan de pago.

**Dónde se escribe el perfil**

1. **El cliente escribe su propio documento `users/{uid}`, validado por las reglas de seguridad.**
2. **Solo el servidor escribe el perfil,** a través de una API. Una única puerta de escritura; el alta dependería de un servicio que aún no existe y añadiría un salto de red a un flujo que ya tiene dos.

**Cuenta a medio crear** (la cuenta existe en Auth y el perfil no llegó a guardarse)

1. **Detectarlo en cada inicio de sesión y llevar al cliente a completar el perfil.** Lo que había escrito se conserva solo en memoria.
2. **Guardar el borrador del perfil en el dispositivo y reintentar.** No funciona en otro dispositivo y deja la cédula en un almacenamiento sin cifrar.
3. **Borrar la cuenta si falla el perfil.** El borrado también puede fallar, y entonces el correo queda ocupado sin salida.
4. **Crear cuenta y perfil en una operación atómica del servidor.** Es la solución correcta en producción; requiere la API.

**Mensajes de error**

1. **Un único mensaje para cualquier rechazo de credenciales, y aviso explícito de «correo ya registrado» en el alta.**
2. **Mensajes genéricos también en el alta.** No revela nada; el cliente que ya tenía cuenta no entiende por qué no puede registrarse.
3. **Mensajes específicos en todas partes.** Más claro; permite averiguar qué correos tienen cuenta.

**Biometría**

1. **Desbloqueo local de una sesión que ya existe.**
2. **Factor de autenticación ante el servidor** (clave ligada al dispositivo). Es lo que usa un banco para autorizar operaciones; exige registro de dispositivos y verificación en el servidor.
3. **Guardar la contraseña en el almacén seguro y reenviarla tras la huella.** Mantiene una copia de la contraseña en el dispositivo.

## Opción seleccionada

La primera opción en cada caso.

**Capas del paquete.** El dominio (entidades, validadores, interfaz del repositorio) es Dart puro. El repositorio orquesta dos puertos, el proveedor de identidad y el almacén de perfiles, y toda llamada pasa por la política de resiliencia ([ADR 0009](0009-politica-de-resiliencia.md)). Firebase Auth, Firestore, `local_auth` y las preferencias del dispositivo están en adaptadores que solo conoce la raíz de composición.

**Qué se declara idempotente.** Iniciar sesión, leer el perfil y pedir el restablecimiento de contraseña se reintentan. Crear la cuenta y guardar el perfil se ejecutan una sola vez.

**Quién escribe qué**

| Dato | Lo escribe | Control |
|---|---|---|
| Credenciales | Firebase Auth | El proveedor |
| Perfil `users/{uid}` | El propio cliente | Reglas de Firestore |
| Cuentas, saldos y movimientos | Solo el servidor | Las reglas niegan toda escritura de clientes |
| Configuración publicada | Solo el servidor | Las reglas niegan toda escritura de clientes |

**Reglas del perfil** (`firebase/firestore.rules`):

- Solo el dueño lee, crea y actualiza su documento. Nadie lo borra desde un cliente.
- Lista cerrada de campos: `fullName`, `nationalId`, `email`, `phone`, `segment`, `interests` y `createdAt`. Un campo fuera de ella, como un saldo o un rol, hace rechazar la escritura.
- Se validan tipos, longitudes, el formato de la cédula y del celular, y que el segmento y los intereses pertenezcan a listas conocidas.
- El correo debe ser el de la cuenta autenticada.
- `createdAt` debe ser la hora del servidor al crear y no puede cambiar después. Tampoco la cédula ni el correo.
- Los intereses no pueden repetirse.

Las pruebas de `firebase/test/` ejecutan 49 casos contra el emulador, permitidos y denegados, para perfiles, cuentas, movimientos y configuración. Se ejecutan en la integración continua.

**Cuenta a medio crear.** Si guardar el perfil falla después de crear la cuenta, el alta se da por hecha (la cuenta no puede deshacerse) y la sesión pasa al estado «perfil pendiente». La aplicación lleva al cliente a un flujo de dos pasos, con lo que había escrito ya cargado y un aviso de que no pudo guardarse. El mismo estado se detecta al iniciar sesión o al restaurar la sesión en cualquier dispositivo, ya sin los datos, que se piden de nuevo. Antes de guardar, el repositorio vuelve a leer el perfil: si la escritura que pareció fallar sí llegó al servidor, se usa ese documento, porque escribir otra vez sería una actualización que las reglas rechazan.

**Mensajes de error.** El inicio de sesión responde «No pudimos validar tus datos. Revisa e intenta de nuevo.» ante cualquier rechazo de credenciales, sin indicar qué campo falló. El restablecimiento de contraseña confirma siempre con el mismo texto, exista o no la cuenta. El alta sí avisa de que el correo ya está registrado.

**Biometría.** El cliente la activa en el tercer paso del alta, si el dispositivo la tiene. La preferencia se guarda por dispositivo y por cuenta. Al restaurar una sesión en ese dispositivo, la aplicación pide la huella o el rostro antes de mostrar nada de la cuenta, también cuando el perfil está pendiente de completar, porque ese formulario muestra el correo. Si la comprobación falla o el dispositivo ya no tiene biometría, la salida es la contraseña: se cierra la sesión y se muestra el inicio de sesión. No se acepta el PIN del dispositivo como sustituto. Si la preferencia no puede leerse, se pide la comprobación.

El bloqueo se aplica **solo al abrir la aplicación en frío**, cuando se restaura la sesión. Al volver desde segundo plano no se vuelve a pedir. Es un límite de alcance asumido: bloquear al reanudar exige decidir un tiempo de inactividad y ocultar el contenido en el selector de aplicaciones, y queda fuera de esta entrega.

**La cédula** es un dato personal. Se valida en el dispositivo con su algoritmo real (provincia, tercer dígito y dígito verificador) y se guarda únicamente en el documento del perfil, que solo su dueño puede leer. No se guarda en el dispositivo y no se envía a la telemetría. Lo que respalda esa afirmación son dos tipos de prueba:

- **Contenido exacto de cada evento.** Las pruebas del repositorio, del registro y del desbloqueo fijan el nombre y los parámetros de cada evento que emiten: restauración de sesión, inicio de sesión y su fallo, alta, perfil no guardado, restablecimiento de contraseña, cierre de sesión, pasos del registro y resultado del desbloqueo. Un parámetro nuevo hace fallar la prueba.
- **Búsqueda de datos personales.** Una prueba del repositorio recorre un inicio de sesión rechazado con un error que cita el correo, un alta, un cierre de sesión, un inicio de sesión y un restablecimiento de contraseña; otra recorre los tres pasos del registro. Ambas fallan si algún evento, registro o informe de error contiene el correo, el nombre, la cédula, el celular o la contraseña de los datos de prueba.

La búsqueda no cubre completar un perfil pendiente ni la restauración de la sesión; de esos dos casos solo está fijado el contenido exacto de sus eventos.

**La escucha de la configuración espera al inicio de sesión.** Las reglas solo permiten leer `config/*` a usuarios autenticados y nada lee la configuración antes de la etapa 6. Suscribirse antes de tener sesión solo produciría fallos de permiso y reintentos. La política de resiliencia y el estado de conectividad sí se instancian ya en la raíz de composición, porque el acceso los usa.

**Navegación.** `go_router` en la aplicación, con una redirección que depende del estado de la sesión: desconocida, sin sesión, bloqueada, con perfil pendiente, no disponible o iniciada. El paquete expone sus rutas y esa función de redirección; la aplicación las monta.

**Dependencias añadidas:** `firebase_auth`, `local_auth`, `go_router`, `flutter_bloc` y `equatable` (igualdad de estados sin código repetido). Para las pruebas de reglas, confinadas a `firebase/`: `@firebase/rules-unit-testing`, `firebase` y `firebase-tools`.

## Trade-offs

- **Se gana:** el alta funciona sin servidor propio, y lo que el cliente puede escribir está acotado por reglas con pruebas.
- **Se gana:** una cuenta nunca queda inutilizable por un fallo a mitad del alta.
- **Se paga:** el aviso de «correo ya registrado» permite comprobar si un correo tiene cuenta. Se acepta por la claridad que da al cliente; lo mitigan la limitación de intentos del proveedor y, en producción, App Check.
- **Se paga:** la cédula se valida por formato, no contra el Registro Civil. Nada prueba que pertenezca a quien la escribe. Un banco real necesita verificación de identidad con documento y prueba de vida.
- **Se paga:** la cédula se guarda en claro en Firestore, protegida por las reglas y por el cifrado en reposo del proveedor. No hay cifrado a nivel de campo.
- **Se paga:** las reglas validan el formato de la cédula, no su dígito verificador. Un cliente modificado podría guardar una cédula con formato válido e inventada.
- **Se paga:** el correo no se verifica. La cuenta queda activa sin comprobar que el cliente controla esa dirección.
- **Se paga:** la cédula no se comprueba contra ningún registro ni se exige que sea única. Dos cuentas pueden declarar la misma, porque las reglas no pueden consultar los perfiles de otros clientes; la unicidad necesita el servidor.
- **Se paga:** el bloqueo biométrico actúa al abrir la aplicación, no al volver desde segundo plano. Quien tome el teléfono con la aplicación ya abierta no encuentra el bloqueo.
- **Se paga:** la biometría protege el acceso a la aplicación en el dispositivo, no las operaciones. No es un segundo factor ante el servidor.
- **Se paga:** la preferencia biométrica es local. En un dispositivo nuevo la sesión se abre con contraseña y sin bloqueo hasta que exista una pantalla para activarlo, prevista en el perfil.
- **Se paga:** la política de contraseñas se comprueba en la aplicación. El proveedor aplica la suya, más laxa, salvo que se configure en la consola.
- **Se paga:** la pantalla de inicio de sesión no muestra el botón de huella del diseño. Sin una sesión que desbloquear no hay nada que la huella pueda abrir; el botón aparece en la pantalla de desbloqueo.

## Impacto a largo plazo

El repositorio es la única pieza que sabe cómo se crea una cuenta. Pasar el alta a una operación atómica del servidor, o añadir verificación de identidad, cambia su implementación y un paso del flujo, no las pantallas ni la navegación. Las reglas del perfil crecerán con cada campo nuevo; las pruebas del emulador son lo que permite cambiarlas sin abrir un hueco.

Convendría revisar la decisión al integrar un proveedor de verificación de identidad, al exigir un segundo factor para operaciones, o si la regulación obliga a cifrar la cédula a nivel de campo o a guardarla fuera del documento del perfil.
