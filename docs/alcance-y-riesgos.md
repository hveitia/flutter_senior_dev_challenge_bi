# Alcance, supuestos, riesgos y escalamiento

Qué pedía el reto, qué se construyó, cómo se comprobó cada cosa y qué se dejó fuera a propósito. Las cifras de pruebas son las de la última verificación completa (`tool/verify.sh`): 1866 pruebas de Dart en nueve paquetes, 615 del servidor y la consola, 110 de las reglas de Firestore y 31 de las herramientas de carga.

«Dispositivo» significa un teléfono Android físico contra el proyecto real de Firebase. En casi todas las comprobaciones el servidor se ejecutaba en local; las que se hicieron contra el servidor desplegado lo dicen. iOS no se compiló ni se probó en ningún momento.

## Requisitos del reto

### Alcance mínimo

| Requisito | Dónde está | Cómo se comprobó | Estado |
| --- | --- | --- | --- |
| Onboarding y autenticación de clientes | `packages/feature_auth`, reglas del perfil en `firebase/firestore.rules` ([ADR 0011](adr/0011-autenticacion-y-perfil.md)) | Pruebas; registro e inicio de sesión en emulador de Android y en dispositivo contra el proyecto real | Cumplido. Sin verificar: el desbloqueo biométrico en un dispositivo y el correo de recuperación de contraseña. El correo no se verifica |
| Gestión de cuentas, saldos y movimientos | `packages/feature_accounts`, API en `apps/backoffice/app/api` ([ADR 0012](adr/0012-lectura-de-cuentas-y-movimientos.md), [0016](adr/0016-movimiento-de-dinero-en-el-servidor.md), [0017](adr/0017-transferencias-en-la-aplicacion.md)) | Pruebas; lectura, filtros, búsqueda, paginación, transferencia, cola sin conexión y alta de cuentas vistas en dispositivo | Cumplido. Solo transferencias entre cuentas propias |
| Personalización dinámica de experiencia, contenido o funcionalidades | `packages/feature_home`, `packages/module_kit`, `contracts/`, Perfil > Personalización ([ADR 0013](adr/0013-registro-de-modulos-y-motor-del-inicio.md)) | Pruebas; cambio de segmento y publicación desde la consola vistos en dispositivo, sin reiniciar la aplicación | Cumplido. La personalización es por segmento e interruptores; no usa el comportamiento del cliente |
| Integración con al menos un servicio o micro aplicativo externo | `packages/feature_services`, páginas en `apps/backoffice/app/partners` ([ADR 0019](adr/0019-mini-aplicaciones-de-aliados.md)) | Pruebas; cotización de seguro, recarga, caída del aliado y apagado del servicio vistos en dispositivo | Cumplido con una salvedad: los dos aliados son simulados y se sirven desde el mismo servidor. El contenedor, la regla de origen y el contrato de mensajes son los que usaría un tercero real |
| Notificaciones push para clientes | `packages/feature_notifications`, envío en `apps/backoffice/lib/server/push.ts` ([ADR 0018](adr/0018-notificaciones-y-bandeja.md)) | Pruebas; envío real a un cliente y a un segmento, bandeja, cambio de segmento, cierre de sesión y segundo cliente en el mismo teléfono vistos en dispositivo | Cumplido en Android. Sin verificar: el texto oculto en la pantalla de bloqueo y la sesión revocada. iOS sin construir |
| Explicar cómo se monitorearía en producción y cómo se detectarían problemas | [operacion/monitoreo.md](operacion/monitoreo.md), [ADR 0010](adr/0010-observabilidad.md), Perfil > Diagnóstico | Los eventos y trazas se emiten y están cubiertos por pruebas de su contenido | Cumplido como explicación. No se comprobó la llegada de los datos a la consola de Firebase y no hay alertas configuradas |
| Describir el comportamiento ante conectividad limitada, alta latencia o indisponibilidad parcial | [operacion/conectividad-degradada.md](operacion/conectividad-degradada.md), [ADR 0009](adr/0009-politica-de-resiliencia.md) | Cada fila del documento indica si se vio en dispositivo o solo en pruebas | Cumplido |
| Pruebas unitarias, de widgets y al menos un flujo E2E crítico | `test/` de cada paquete; `apps/mobile/integration_test/transfer_flow_test.dart` | 1866 pruebas de Dart en CI. El flujo E2E (iniciar sesión, transferir, ver el movimiento) pasó en dispositivo contra servicios reales | Parcial en el E2E: la versión actual, que transfiere y devuelve para poder repetirse, no tiene todavía una ejecución válida; la que pasó era de un solo sentido. No corre en CI |
| Documentar el uso de herramientas de IA y su impacto | [ia/registro-uso-ia.md](ia/registro-uso-ia.md) | Resumen de las herramientas, el método de trabajo, las decisiones del autor y el impacto en productividad, calidad, documentación y pruebas | Cumplido |
| Demostrar el comportamiento degradado: estados de carga, reintentos, caché y recuperación | Laboratorio de resiliencia de la consola y de `firebase/seed/publish-config.mjs`; compilación con `ALLOW_FAULT_INJECTION` | Visto en dispositivo: esqueletos, sin conexión con datos guardados, conexión lenta, falla parcial, recuperación, transferencia en cola que se liquida sola, aliado caído | Cumplido. Sin ver en dispositivo: el error de pantalla completa del inicio y los fallos publicados desde la consola (se publicaron con la herramienta de desarrollo; desde la consola se vio en el teléfono un cambio de orden de módulos) |

### Entregables

| Entregable | Dónde está | Estado |
| --- | --- | --- |
| Código fuente con historial de desarrollo | Este repositorio; historial lineal en `main` | Cumplido |
| README con instrucciones para configurar, ejecutar, probar y colaborar | [README.md](../README.md) | Cumplido. El modo local con emuladores permite ejecutar todo sin acceso al proyecto de Firebase |
| Documentación de arquitectura y decisiones técnicas | [adr/](adr/) (19 decisiones con los cinco campos pedidos), [arquitectura/](arquitectura/) | Cumplido |
| Documentación de estrategia de despliegue y operación | [operacion/despliegue.md](operacion/despliegue.md) y el resto de [operacion/](operacion/) | Cumplido. El servidor (consola, API de clientes y páginas de aliados) está desplegado como demostración en Firebase App Hosting; la aplicación no está publicada en ninguna tienda y el resto es estrategia |
| Demostración funcional | Servidor desplegado (<https://backoffice--flutter-challenge-bi.us-east4.hosted.app>), [demo/guion.md](demo/guion.md) y modo local | Cumplido. La consola desplegada se usa con una cuenta de administrador que se entrega por privado. La aplicación no está en una tienda: se instala desde una compilación que apunta al servidor desplegado, o desde el código en modo local |
| Diagramas de componentes, flujos y dependencias | [arquitectura/componentes.md](arquitectura/componentes.md), [arquitectura/flujos.md](arquitectura/flujos.md), [arquitectura/publicar-configuracion.md](arquitectura/publicar-configuracion.md) | Cumplido |
| Supuestos, riesgos técnicos y estrategia de escalamiento | Este documento | Cumplido |
| Trunk Based Development | [ADR 0006](adr/0006-trunk-based-development.md) | Cumplido: una rama, commits pequeños, verificación antes de cada commit y CI en cada push. Son más de 280 commits en dos días, subidos por lotes; dos lotes locales con commits defectuosos se repararon antes de publicarse. El ADR describe cómo se ve el historial y por qué |

### Bonus

| Bonus | Qué hay | Estado |
| --- | --- | --- |
| Capacidades avanzadas de personalización o asistencia | Segmentos, intereses, composición del inicio por segmento, módulo «Para ti» | Parcial. No hay asistente ni recomendaciones calculadas a partir del comportamiento |
| Experiencias generadas dinámicamente | El inicio se arma en tiempo de ejecución desde un documento publicado; módulos desconocidos se omiten | Cumplido |
| Automatizaciones para desarrollo, pruebas, despliegue o documentación | Hook de verificación acotada, dos flujos de CI, pruebas de reglas con emulador, Dependabot para las acciones, `tool/local-stack.sh`, herramientas de carga y publicación | Parcial. El servidor se despliega solo con cada push a `main`; no hay canalización de publicación de la aplicación ni publicación automática de la documentación |

## Decisiones conscientes de alcance

Lo que se dejó fuera y por qué. Cada una se tomó para proteger lo que más pesa en el reto: el inicio dirigido por configuración, el dinero movido de forma segura y los estados degradados.

| Fuera de alcance | Por qué | Qué costaría añadirlo |
| --- | --- | --- |
| iOS | Sin tiempo para compilar, firmar y probar en un segundo sistema; las notificaciones exigen una clave APNs | Compilar, ajustar permisos, el canal de ajustes del sistema y la limpieza de la vista web, que en iOS no cubre todo |
| Tema oscuro | Duplica las combinaciones de color que las pruebas de contraste deben cubrir | Un segundo juego de tokens; las pruebas de contraste ya recorren una lista de combinaciones |
| Traducciones | La aplicación tiene un solo público y un solo idioma | Extraer los textos, hoy agrupados por pantalla, a recursos |
| Pruebas de imagen | Las fuentes se dibujan distinto en macOS y en el Linux de la CI; darían fallos falsos | Ejecutarlas solo en la CI con imágenes generadas allí |
| Pilas de navegación independientes por pestaña | No aportaban a ningún requisito | Cambiar el tipo de ruta contenedora |
| Verificación de correo e identidad | Requiere un proveedor de identidad y un flujo de espera | Exigir correo verificado en las reglas y en el alta de cuentas |
| Transferencias a terceros | Exigen beneficiarios, límites y prevención de fraude | El servidor ya decide en una función pura; habría que ampliar el modelo |
| Firma de publicación y tiendas | No se entrega una aplicación publicada | Claves en un almacén de secretos y una canalización ([operacion/despliegue.md](operacion/despliegue.md)) |
| Un entorno de producción para el servidor | Lo desplegado es una demostración: un solo servicio para consola, API y aliados, sin dominio propio ni entorno previo | Separar consola, API y aliados, y añadir un entorno previo con promoción manual |
| Límites de frecuencia y App Check | No cabían en el plazo. La demostración está expuesta sin ellos, con registro abierto y un depósito de demostración por cada alta; lo acota un tope de instancias | Imprescindibles antes de un uso real; mientras tanto, cuotas de alta y alerta de presupuesto en la consola de Firebase |
| Aliados reales | No hay un tercero con quien integrar | El contenedor y el contrato no cambian; cambia el origen |
| Cancelar una operación en curso y cortacircuitos por servicio | El peor caso está acotado en unos 25 segundos | Una señal de cancelación en la política de resiliencia ([ADR 0009](adr/0009-politica-de-resiliencia.md)) |
| Bloqueo biométrico al volver de segundo plano | Se priorizó el bloqueo al abrir la aplicación | Observar el ciclo de vida y un tiempo de gracia |

## Supuestos

- El banco opera en Ecuador, en dólares, con cédula de diez dígitos y celulares que empiezan por 09.
- Los datos son de demostración: los saldos de apertura no tienen valor real y el registro es abierto.
- Un cliente pertenece a un segmento a la vez y lo elige él mismo. En un banco lo asignaría el negocio.
- La configuración publicada no contiene datos sensibles: cualquier cliente autenticado puede leerla.
- El reloj del dispositivo es razonable. La antigüedad de los datos guardados se calcula con él.
- Quien evalúa puede no tener acceso al proyecto de Firebase; por eso existe el modo local.
- Los identificadores de cliente de Firebase versionados no son secretos; el control son las reglas y la sesión.

## Riesgos técnicos

| Riesgo | Probabilidad | Impacto | Mitigación hoy | Lo que falta |
| --- | --- | --- | --- | --- |
| Doble movimiento de dinero por un reintento | Baja | Alto | Identificador de orden como clave de idempotencia, una sola transacción, identificadores fijos de los movimientos, y una orden que pudo salir nunca se encola | Conciliación periódica entre órdenes y movimientos |
| Una configuración publicada deja a los clientes sin inicio | Media | Alto | Validación contra el contrato al publicar, lector tolerante, última configuración válida, cuatro orígenes de respaldo, control de versión al publicar | Publicación por etapas y vista previa en un dispositivo real antes de publicar |
| Abuso del registro abierto (creación masiva de cuentas con saldo de demostración) | Alta si se expone | Medio en demostración, alto en producción | Documentado; reglas estrictas | Correo verificado, App Check, límites de frecuencia, cuotas en el proyecto |
| Datos de un cliente al alcance del siguiente en un teléfono compartido | Baja | Alto | Borrado por pasos al terminar toda sesión, con registro de lo pendiente; el dispositivo recuerda para quién está registrado y se limpia antes de registrar a otro. Límite: si el borrado falla o agota su tiempo se reintenta antes de que la sesión siguiente lea nada, y si vuelve a fallar la sesión continúa y la copia queda en el disco. No es alcanzable desde la aplicación, porque cada consulta va acotada al identificador del cliente y las reglas lo exigen, pero sigue presente en el dispositivo | Comprobar en dispositivo el borrado de la vista web; cifrar la copia local |
| Contenido de un aliado que suplanta al banco dentro de la vista web | Media con aliados reales | Alto | Barra del banco fuera del alcance de la página, marco rotulado, origen fijo al compilar, contexto mínimo, mensajes validados | Revisión de cada aliado; en Android la intercepción puede no cubrir marcos internos ni envíos de formulario, y no se ejercitó |
| Acoplamiento a Firebase | Segura | Medio | Firebase solo aparece en adaptadores detrás de interfaces, y una prueba de frontera lo vigila en cada paquete | Sustituir los adaptadores; el modelo de datos es lo costoso de migrar |
| Límites de Firestore (consultas, documentos de 1 MiB, coste por lectura) | Media al crecer | Medio | Movimientos paginados, una colección plana por cliente con su índice | Historial antiguo en otro almacén; agregados calculados en el servidor |
| El tipo de módulo y el destino son texto, sin comprobación del compilador | Media | Bajo | Un tipo desconocido se omite y se informa una vez; un destino sin pantalla oculta la acción | Generar las constantes desde el contrato |
| Pruebas escritas después del código en varias etapas | Ocurrió | Medio | Revisiones independientes por etapa; cada defecto se reprodujo con una prueba antes de corregirse; validación por mutación | Mantener la prueba primero como norma, que es donde menos defectos aparecieron |
| Funciones solo verificadas con pruebas, no en dispositivo | Ocurre | Medio | Cada documento separa lo visto en dispositivo de lo que no | iOS completo; pantalla de bloqueo; biometría; sesión revocada |
| Un solo servidor para consola, API y aliados | Segura | Medio | Sesiones separadas: un token de cliente no abre la consola ni al revés; las páginas de aliados no importan código de la consola | Separarlos en tres despliegues |

## Estrategia de escalamiento

### Equipos y código

- **Un paquete por dominio, con el compilador como frontera.** Ningún dominio depende de otro; se encuentran en `module_kit` (el contrato) y en `apps/mobile` (la raíz de composición). Una prueba por paquete impide que el dominio importe Firebase o complementos fuera de sus adaptadores.
- **Un equipo nuevo añade un dominio sin tocar el inicio:** crea su paquete, registra sus módulos y rutas, y la raíz de composición lo monta. El inicio no cambia.
- **Verificación proporcional.** El hook ejecuta solo las pruebas de lo que un commit afecta; la CI lo ejecuta todo. Al crecer, la CI se dividiría por paquete con la misma tabla de dependencias.
- **De commits directos a ramas cortas.** Con más de una persona, ramas de menos de un día con revisión, la misma verificación y la misma regla de `main` siempre publicable.

### Contrato de configuración

- El esquema de `contracts/` es la fuente única: la consola valida contra él y la aplicación lo lee con tolerancia.
- **Cambios compatibles** (un tipo de módulo o una propiedad nuevos) no suben la versión de esquema: las versiones anteriores los omiten.
- **Cambios incompatibles** suben `schemaVersion`. Las aplicaciones que no lo entienden conservan su última configuración válida, así que el orden es publicar primero la aplicación y después la configuración.
- Al crecer: publicación por porcentaje de clientes, programación de publicaciones y un segmento asignado por el negocio en lugar de elegido por el cliente.

### Datos

- Hoy cada cliente tiene sus documentos bajo `users/{uid}` y la aplicación los escucha en tiempo real. Sirve para la lectura y para la caché sin conexión.
- Los límites conocidos: una escucha por pantalla y cliente, coste por documento leído, y transacciones que compiten sobre los documentos de cuenta.
- El camino: mantener Firestore como proyección de lectura para la aplicación y mover el libro mayor a un sistema transaccional detrás de la API, que ya es el único punto que escribe dinero. La aplicación no cambiaría: lee la proyección y pide operaciones a la API.

### Servidor

- La API de clientes no guarda estado entre peticiones, así que escala en horizontal.
- Antes de exponerla: App Check, límites de frecuencia por cliente y por dirección, y separar su despliegue del de la consola.
- El aviso de una transferencia se escribe después de responder y nunca afecta a la respuesta; con volumen pasaría a una cola.
- El envío a un segmento escribe la bandeja de hasta 500 clientes en un lote. Más allá de eso, un proceso en segundo plano por lotes.

### Observabilidad

- Lo que ya se emite (eventos por dominio, trazas de carga y de liquidación, versión y origen de la configuración en cada informe) permite crear paneles y alertas sin tocar la aplicación.
- Falta crear los umbrales, comprobar la llegada de los datos y correlacionar el identificador de petición del servidor con la traza de la aplicación.
