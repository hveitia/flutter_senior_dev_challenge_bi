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

"Aceptada" significa que la decisión está tomada. Cada ADR indica qué parte está implementada y qué parte está planificada.

## Uso de inteligencia artificial

- [Registro de uso de IA](ia/registro-uso-ia.md): qué se delegó, qué decidió o corrigió el autor y qué impacto tuvo.

## Pendiente de documentar

Estos documentos se escriben cuando exista lo que describen:

- Diagramas de componentes, flujos y dependencias.
- Estrategia de despliegue y operación.
- Monitoreo en producción y detección de problemas.
- Comportamiento ante conectividad limitada, alta latencia e indisponibilidad parcial.
- Supuestos, riesgos técnicos y estrategia de escalamiento.
- Decisiones conscientes de alcance.
