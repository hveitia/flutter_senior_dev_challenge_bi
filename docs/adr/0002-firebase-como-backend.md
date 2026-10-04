# 0002. Firebase como backend

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** existe el proyecto `flutter-challenge-bi`, la base de datos Firestore en `us-east1`, las reglas de seguridad iniciales, el proveedor de correo y contraseña habilitado y la inicialización de Firebase en la aplicación. La aplicación usa Auth, Firestore, Cloud Messaging, Crashlytics, Analytics y Performance; las decisiones posteriores describen cada uso. Existe además un modo local sobre los emuladores de Auth y Firestore (`tool/local-stack.sh`).

## Problema a resolver

La prueba no valora soluciones basadas solo en datos simulados: exige evidencia de interacción real con servicios. La solución necesita autenticación, datos de cuentas y movimientos, cambios de configuración que lleguen a la aplicación sin publicarla, notificaciones push y comportamiento útil sin conexión. No existe un equipo de backend y el plazo es de dos días.

## Alternativas evaluadas

1. **Firebase (Auth, Firestore, Cloud Messaging).** Servicios reales y gestionados, escucha en tiempo real y caché local sin conexión incluidas en el SDK. Acopla la capa de datos a un proveedor y a un modelo documental.
2. **Supabase.** Base relacional, más cercana a un modelo contable. El cliente oficial para Flutter no incluye persistencia local sin conexión; habría que añadirla con una solución adicional. Tampoco incluye un servicio de notificaciones push.
3. **Backend propio (API y base relacional).** Control total y modelo de datos fiel a un banco. Su construcción y despliegue consumiría el plazo que debe dedicarse a la aplicación, que es lo evaluado.
4. **Servidor de datos simulados.** El más barato. Es exactamente lo que la prueba indica que no puntúa.

## Opción seleccionada

La opción 1, Firebase:

- **Auth** para registro y autenticación con correo y contraseña.
- **Firestore** para cuentas, movimientos y el documento de configuración de la experiencia. La aplicación escucha los cambios en tiempo real y usa la persistencia local del SDK como caché.
- **Cloud Messaging** para notificaciones push.
- **Crashlytics, Analytics y Performance** para observabilidad.

Las reglas de seguridad niegan todo por defecto. Un cliente autenticado solo puede leer su propio documento de usuario y lo que cuelga de él, y la configuración publicada. Ningún cliente escribe saldos, cuentas ni movimientos: esos cambios los hace el servidor ([ADR 0004](0004-backoffice-y-api-en-nextjs.md)).

La colección `config/*` es legible por cualquier usuario autenticado y el registro con correo y contraseña está abierto, de modo que cualquier persona puede crear una cuenta y leerla. Por eso el documento de configuración no debe contener nunca datos sensibles: solo describe la composición de la experiencia.

## Trade-offs

- **Se gana:** servicios reales desde el primer día, tiempo real y caché sin conexión sin código propio.
- **Se paga:** dependencia del proveedor. Se mitiga con interfaces de repositorio en la capa de dominio de cada paquete: Firestore solo aparece en la capa de datos.
- **Se paga:** un modelo documental no es el que usaría un núcleo bancario para un libro contable. Es aceptable para una demostración y está aislado tras los repositorios.
- **Se paga:** Cloud Functions exige un plan de pago. La lógica de servidor se ubica en la API de Next.js, que no lo requiere.
- **Restricción:** la región de Firestore (`us-east1`) no puede cambiarse una vez creada la base de datos.

## Impacto a largo plazo

Sustituir Firebase por las API reales del banco implica reescribir la capa de datos de cada paquete de dominio, no la presentación ni el dominio. La caché sin conexión y el tiempo real tendrían que resolverse entonces con otra tecnología, y ese es el costo principal de una migración.

Convendría revisar la decisión al integrar sistemas bancarios reales o si las reglas de seguridad crecen hasta ser difíciles de auditar.
