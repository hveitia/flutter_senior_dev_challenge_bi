# Documentación

Índice de la documentación del proyecto. Para ejecutar el sistema, empieza por el [README de la raíz](../README.md); para saber qué se construyó y qué no, por [Alcance, supuestos, riesgos y escalamiento](alcance-y-riesgos.md).

## Alcance y demostración

- [Alcance, supuestos, riesgos y escalamiento](alcance-y-riesgos.md): cada requisito del reto con dónde está, cómo se comprobó y su estado; decisiones conscientes de alcance; supuestos; riesgos técnicos y estrategia de escalamiento.
- [Guion de la demostración](demo/guion.md): recorrido con tiempos, comandos y alternativas si algo falla, y los ejercicios probables en vivo con el archivo y la prueba que toca cada uno.

## Decisiones de arquitectura

Cada decisión relevante se registra como un ADR con cinco campos: problema, alternativas evaluadas, opción seleccionada, trade-offs e impacto a largo plazo. La plantilla está en [`adr/0000-plantilla.md`](adr/0000-plantilla.md).

| N.º | Decisión | Estado |
|---|---|---|
| [0001](adr/0001-monorepo-workspaces-paquetes-por-dominio.md) | Monorepo con workspaces y paquetes por dominio | Aceptada |
| [0002](adr/0002-firebase-como-backend.md) | Firebase como backend | Aceptada |
| [0003](adr/0003-gestion-de-estado-con-bloc.md) | Gestión de estado con Bloc | Aceptada |
| [0004](adr/0004-backoffice-y-api-en-nextjs.md) | Consola web y API de servidor en Next.js | Aceptada |
| [0005](adr/0005-home-dirigido-por-configuracion.md) | Inicio dirigido por configuración con registro de módulos | Aceptada |
| [0006](adr/0006-trunk-based-development.md) | Trunk Based Development con commits directos a `main` | Aceptada |
| [0007](adr/0007-sistema-de-diseno.md) | Sistema de diseño como paquete, con tokens verificados y accesibilidad comprobada por pruebas | Aceptada |
| [0008](adr/0008-contrato-de-configuracion.md) | Contrato de configuración publicado, con lectura tolerante a versiones | Aceptada |
| [0009](adr/0009-politica-de-resiliencia.md) | Una única política de resiliencia, con inyección de fallos para demostración | Aceptada |
| [0010](adr/0010-observabilidad.md) | Observabilidad detrás de una interfaz, sin datos del cliente en los registros | Aceptada |
| [0011](adr/0011-autenticacion-y-perfil.md) | Autenticación con Firebase Auth y perfil escrito por el cliente bajo reglas | Aceptada |
| [0012](adr/0012-lectura-de-cuentas-y-movimientos.md) | Lectura de cuentas y movimientos en tiempo real, con la copia local de Firestore como caché | Aceptada |
| [0013](adr/0013-registro-de-modulos-y-motor-del-inicio.md) | Registro de módulos y motor del inicio, con un estado por conjunto de datos | Aceptada |
| [0014](adr/0014-consola-de-experiencia.md) | Consola de experiencia: validación desde el contrato y publicación con control de versión | Aceptada |
| [0015](adr/0015-acceso-de-administradores.md) | Acceso de administradores y credenciales del servidor de la consola | Aceptada |
| [0016](adr/0016-movimiento-de-dinero-en-el-servidor.md) | Movimiento de dinero en el servidor: solicitud pendiente, idempotencia y una sola transacción | Aceptada |
| [0017](adr/0017-transferencias-en-la-aplicacion.md) | Transferencias en la aplicación: cliente de API, cola sin conexión y prueba de extremo a extremo | Aceptada |
| [0018](adr/0018-notificaciones-y-bandeja.md) | Notificaciones push y bandeja del cliente escrita por el servidor | Aceptada |
| [0019](adr/0019-mini-aplicaciones-de-aliados.md) | Servicios y mini aplicaciones de aliados en un contenedor con origen permitido | Aceptada |

"Aceptada" significa que la decisión está tomada. Cada ADR indica qué parte está implementada y cómo se comprobó.

### Etapas de construcción

Los documentos citan las etapas por su número. El trabajo se hizo en once, cada una vertical y publicada al cerrarse:

| Etapa | Qué entregó | Decisiones |
|---|---|---|
| 1. Cimientos | Repositorio, workspace, Firebase, integración continua y hook | 0001 a 0006 |
| 2. Sistema de diseño | Tokens, tema y componentes base, con pruebas de accesibilidad | 0007 |
| 3. Plataforma | Contrato de configuración, política de resiliencia, conectividad y telemetría | 0008 a 0010 |
| 4. Acceso | Registro, inicio de sesión, perfil y sus reglas | 0011 |
| 5. Cuentas y movimientos | Lectura en tiempo real con caché y estados degradados | 0012 |
| 6. Inicio dinámico | Registro de módulos y motor del inicio por segmento | 0013 |
| 7. Consola de experiencia | Consola web, publicación de configuración y envío de notificaciones | 0014, 0015 |
| 8. Transferencias | API de clientes, flujo en la aplicación y cola sin conexión | 0016, 0017 |
| 9. Notificaciones | Push, bandeja y registro del dispositivo | 0018 |
| 10. Servicios | Catálogo y mini aplicaciones de aliados | 0019 |
| 11. Cierre | Modo local con emuladores, despliegue de la demostración y documentación final | |

## Arquitectura

- [Componentes y dependencias](arquitectura/componentes.md): los paquetes de la aplicación móvil, de qué depende cada uno según sus `pubspec.yaml`, qué aporta cada dominio al inicio y qué comparten la consola y la aplicación.
- [Flujo: publicar la configuración y recomponer el inicio](arquitectura/publicar-configuracion.md): la secuencia desde que un administrador publica en la consola hasta que cambia la pantalla de un teléfono.
- [Flujos principales](arquitectura/flujos.md): registro y alta de cuentas, transferencia con conexión, transferencia en cola, notificación con bandeja y mini aplicación de un aliado.

## Operación

- [Estrategia de despliegue y operación](operacion/despliegue.md): entornos, publicación de la aplicación desde `main`, servidor, reglas, reversión por componente, guía ante incidentes y lo que falta para producción. El servidor está desplegado como demostración; el resto es estrategia.
- [Consola de experiencia](operacion/backoffice.md): configuración, ejecución, pruebas y despliegue.
- [API de clientes](operacion/api.md): rutas, contrato, códigos de error y cómo llega la aplicación a ella en desarrollo y en el servidor desplegado.
- [Monitoreo en producción](operacion/monitoreo.md): cómo se detectarían problemas operativos y de experiencia, y qué está implementado hoy.
- [Comportamiento con conectividad degradada](operacion/conectividad-degradada.md): qué hace la aplicación sin conexión, con alta latencia y con un servicio caído, separando lo visto en un dispositivo de lo cubierto solo por pruebas y de lo no hecho.

## Uso de inteligencia artificial

- [Uso de IA en el desarrollo](ia/registro-uso-ia.md): herramientas, método de trabajo, decisiones del autor e impacto.

## Lo que la documentación no cubre

- El servidor está desplegado como demostración y [su despliegue está documentado](operacion/backoffice.md#despliegue-en-firebase-app-hosting). No hay un entorno de producción ni publicación en tiendas, porque no se hicieron: [la estrategia](operacion/despliegue.md) describe cómo serían.
- En iOS la aplicación compila, se instala y funciona en un iPhone físico: el autor la recorrió allí sin encontrar fallos. Las comprobaciones detalladas que citan los documentos se hicieron en Android y no se repitieron una por una en iOS; las notificaciones push no están configuradas allí.
