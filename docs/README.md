# Documentación

Índice de la documentación del proyecto. Se amplía al cerrar cada etapa.

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

"Aceptada" significa que la decisión está tomada. Cada ADR indica qué parte está implementada y qué parte está planificada.

## Arquitectura

- [Componentes y dependencias](arquitectura/componentes.md): los paquetes de la aplicación móvil, de qué depende cada uno, qué aporta cada dominio al inicio y qué comparten la consola y la aplicación.
- [Flujo: publicar la configuración y recomponer el inicio](arquitectura/publicar-configuracion.md): la secuencia desde que un administrador publica en la consola hasta que cambia la pantalla de un teléfono.

## Operación

- [Consola de experiencia](operacion/backoffice.md): configuración, ejecución, pruebas y despliegue.
- [API de clientes](operacion/api.md): rutas, contrato, códigos de error y cómo llega la aplicación a ella en desarrollo y en un despliegue.
- [Monitoreo en producción](operacion/monitoreo.md): cómo se detectarían problemas operativos y de experiencia, y qué está implementado hoy.
- [Comportamiento con conectividad degradada](operacion/conectividad-degradada.md): qué hace la aplicación sin conexión, con alta latencia y con un servicio caído, separando lo visto en un dispositivo de lo cubierto solo por pruebas y de lo planificado.

## Uso de inteligencia artificial

- [Registro de uso de IA](ia/registro-uso-ia.md): qué se delegó, qué decidió o corrigió el autor y qué impacto tuvo.

## Pendiente de documentar

Estos documentos se escriben cuando exista lo que describen:

- Diagramas de la API de clientes y de los flujos de transferencias (en línea y en cola) y notificaciones.
- Estrategia de despliegue.
- Comportamiento ante conectividad limitada, alta latencia e indisponibilidad parcial del inicio, las transferencias y los servicios de aliados (el de acceso, cuentas y movimientos ya está escrito).
- Supuestos, riesgos técnicos y estrategia de escalamiento.
- Decisiones conscientes de alcance.
