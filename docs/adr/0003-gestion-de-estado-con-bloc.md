# 0003. Gestión de estado con Bloc

- **Estado:** Aceptada
- **Fecha:** 2026-10-03
- **Implementación:** planificada. Todavía no hay estado de aplicación; se introduce con el primer paquete de dominio.

## Problema a resolver

La aplicación necesita estados explícitos y comprobables: carga, datos, datos en caché, error parcial, error total y recuperación. Además, el inicio se compone de módulos independientes, y la falla de uno no debe impedir que los demás se muestren. La gestión de estado es un criterio de evaluación, y durante la demostración pueden solicitarse cambios y diagnósticos en vivo.

## Alternativas evaluadas

1. **Bloc y Cubit (`flutter_bloc`).** Estados y transiciones explícitos, flujo unidireccional, pruebas directas con `bloc_test` y un punto único (`BlocObserver`) para observar transiciones y errores. Requiere más clases por funcionalidad.
2. **Riverpod.** Menos código repetitivo e inyección de dependencias integrada. Las transiciones de estado quedan menos explícitas y la trazabilidad depende de cómo se escriba cada proveedor.
3. **Provider con `ChangeNotifier`.** Simple y conocido. El estado mutable y las notificaciones manuales dificultan modelar y probar los estados degradados.

## Opción seleccionada

La opción 1, `flutter_bloc`.

- **Cubit** cuando el estado cambia por llamadas directas; **Bloc** cuando los eventos importan por sí mismos.
- **Un Bloc por módulo del inicio**, más un Cubit que escucha el documento de configuración. Cada módulo carga, falla y reintenta por separado.

Es además la herramienta que el autor domina, lo que pesa en un contexto donde hay que explicar y modificar el código en vivo.

## Trade-offs

- **Se gana:** la falla parcial es consecuencia de la estructura y no de lógica especial; cada estado degradado es un caso de prueba.
- **Se gana:** un observador único conecta las transiciones y los errores con la observabilidad.
- **Se paga:** más archivos y más ceremonia por funcionalidad que con las alternativas.
- **Se paga:** Bloc no resuelve la inyección de dependencias, que se gestiona aparte en la raíz de composición.

## Impacto a largo plazo

El patrón es uniforme entre dominios, lo que facilita que equipos distintos lean el código de otros. Los estados explícitos sirven como documentación del comportamiento esperado en cada escenario degradado.

Convendría revisar la decisión si la ceremonia frena de forma medible el desarrollo de funcionalidades simples, en cuyo caso Cubit ya cubre la mayoría de esos casos sin cambiar de librería.
