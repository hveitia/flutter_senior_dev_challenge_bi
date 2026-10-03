# Registro de uso de IA

Este documento registra cómo se usaron herramientas de IA durante el desarrollo y qué impacto tuvieron. Se actualiza al cerrar cada etapa, no al final, para que refleje lo que ocurrió y no una reconstrucción.

## Herramientas

| Herramienta | Uso |
|---|---|
| Asistente de programación con IA, usado desde la terminal | Análisis del enunciado, propuestas de arquitectura, revisión de diseños, generación de código, pruebas y documentación |
| Modelo generativo de diseño | Generación de las pantallas y del sistema de diseño a partir de un encargo escrito |

## Principio de trabajo

El autor dirige y decide; la IA propone y ejecuta. Toda decisión de arquitectura fue aprobada de forma explícita por el autor antes de escribir código, y al cierre de cada etapa el autor revisa lo construido para poder explicarlo y modificarlo en la demostración.

## Decisiones: qué propuso la IA y qué decidió el autor

| Tema | Propuesta de la IA | Decisión del autor |
|---|---|---|
| Alcance | Reducir la idea inicial de tres artefactos: priorizar la aplicación, limitar la consola a una pantalla y sustituir el sitio de documentación por Markdown en el repositorio | Aceptó el recorte, pero mantuvo una consola propia en lugar de usar solo la consola de Firebase |
| Tecnología de la consola | Flutter Web, para compartir modelos con la aplicación | La rechazó y eligió Next.js. El análisis posterior de la IA respaldó la elección del autor (ver [ADR 0004](../adr/0004-backoffice-y-api-en-nextjs.md)) |
| Backend | Firebase | Aceptada |
| Cuenta del proyecto de Firebase | La IA detectó que la sesión de la CLI correspondía a una cuenta distinta de la esperada y se detuvo a preguntar antes de crear el proyecto | El autor confirmó la cuenta |
| Gestión de estado | Preguntó cuál dominaba el autor | Bloc |
| Arquitectura | Monorepo con paquetes por dominio, registro de módulos y API de servidor para transferencias | Aprobada tras revisarla |
| Idioma de la documentación | Español neutro | Aceptada |

## Aportes concretos de la IA

- **Lectura del enunciado.** Señaló detalles fáciles de pasar por alto: las soluciones basadas solo en datos simulados no se valoran, el comportamiento ante conectividad degradada se pide dos veces (describirlo y demostrarlo), y en la demostración pueden solicitarse cambios en vivo.
- **Paleta y accesibilidad.** Extrajo los colores del sitio público del banco y calculó que el naranja de marca `#EA8E29` con texto blanco da un contraste de 2.5:1, por debajo del mínimo AA de 4.5:1. De ahí salió la regla de usar texto oscuro sobre naranja y un naranja más oscuro para enlaces.
- **Encargo de diseño.** Redactó las instrucciones para el modelo de diseño, incluyendo los estados degradados como pantallas obligatorias.
- **Revisión de los diseños, primera pasada.** Detectó que elementos evaluados quedaban fuera de las capturas, controles nativos del navegador, flujos sin salida (un segmento no podía llegar a transferir) y huecos en el contrato de configuración. Resultado: 45 correcciones.
- **Revisión de los diseños, segunda pasada.** Verificó cada corrección contra las pantallas y los archivos, no contra el registro de cambios que entregó el modelo de diseño. De 45 puntos, 41 quedaron corregidos y 4 parciales, aunque el registro de cambios los declaraba todos como hechos.
- **Etapa 1.** Generó la estructura del repositorio, la configuración de Firebase, la integración continua, el hook de verificación y el borrador de las decisiones de arquitectura. Antes de la primera subida al repositorio público se ejecutó una revisión de seguridad independiente sobre el árbol y el historial completos. No encontró bloqueos y dio lugar a tres cambios de endurecimiento: acciones de integración continua fijadas por SHA de commit, copias de seguridad de Android desactivadas y límites de seguridad conocidos documentados.
- **Etapa 2.** Generó el paquete del sistema de diseño: tokens, tema, diez componentes y sus pruebas, escribiendo cada prueba antes que su implementación. Propuso que `ColorScheme.primary` fuera el naranja apto para texto y no el relleno de marca, para que los componentes de Material cumplan el contraste sin intervención ([ADR 0007](../adr/0007-sistema-de-diseno.md)). Para comprobar que las pruebas de accesibilidad detectan errores reales, pintó temporalmente una etiqueta con el naranja de marca: la prueba de contraste falló con 2,2:1 y el cambio se revirtió. Antes de subir la etapa se ejecutaron dos revisiones independientes, una sobre la fiabilidad de las pruebas y otra sobre la legibilidad del código. No encontraron bloqueos y dieron lugar a estos cambios:
  - **Dos defectos de accesibilidad corregidos.** El campo de texto con error se anunciaba de nuevo en cada pulsación, y el paso de un botón al estado de carga no se anunciaba. Cada uno quedó fijado por una prueba que falla sin la corrección.
  - **Pruebas más exigentes.** Casos límite del formateo de importes (no revelaron ningún defecto), comprobación real de la independencia del idioma del dispositivo y una prueba de activación por teclado del botón en carga.
  - **Código más simple.** Los tamaños sueltos de los componentes pasaron a ser tokens, los colores de cada tono quedaron con un único origen y la utilidad de contraste salió de la API pública.
  - **Verificación más estricta.** `tool/verify.sh` falla si un paquete del workspace no tiene pruebas o no está declarado, en lugar de omitirlo.

## Límites observados

- El paquete de diseño incluía validaciones declaradas por el propio modelo, sin un procedimiento que las respaldara. No se tomaron como evidencia.
- El prototipo de diseño contenía decisiones que no deben copiarse en la aplicación, como navegar comparando textos en lugar de destinos. Se identificaron en la revisión.
- La primera recomendación de tecnología para la consola no era la mejor. La corrigió el criterio del autor.
- En la etapa 2, las pruebas automáticas pasaban y aun así había un defecto visual: el espaciado entre letras por defecto de Material se filtraba en la tipografía. Solo apareció al renderizar la galería y revisarla. Se corrigió con una prueba que ahora lo impide.
- La revisión de la galería en el teléfono no pudo hacerse en la etapa 2 porque el dispositivo estaba bloqueado. Se sustituyó por un renderizado fuera del dispositivo con las fuentes reales, que no equivale a verla en el teléfono.
- En la misma etapa, las 229 pruebas del paquete pasaban con dos defectos de accesibilidad presentes. Una prueba comprobaba que el error formaba parte de la etiqueta del campo, pero no cuándo se anunciaba; otra decía verificar un estado «ocupado» que nada afirmaba. Los encontró una revisión independiente, no quien escribió el código.
- La IA introdujo caracteres invisibles (espacio de no separación) directamente en el código fuente. Se detectaron al analizar el código y se reemplazaron por secuencias de escape explícitas.

## Impacto por etapa

Valoración cualitativa. No se registran métricas cuantitativas porque no se midieron.

| Etapa | Productividad | Calidad | Documentación | Pruebas |
|---|---|---|---|---|
| Análisis y diseño | Encargo de diseño y dos revisiones en una sesión | La revisión detectó defectos de accesibilidad y de flujo antes de escribir código | Las decisiones quedaron registradas mientras se tomaban | No aplica |
| 1. Cimientos | Estructura, Firebase, integración continua y hook listos en una sesión | Análisis estático estricto y verificación previa a cada commit desde el inicio | README y seis decisiones de arquitectura redactados por la IA a partir de lo decidido por el autor | Prueba de widget de la aplicación base escrita antes que la implementación |
| 2. Sistema de diseño | Tokens, tema, diez componentes y galería en una sesión | Las reglas de accesibilidad son pruebas que fallan, no recomendaciones. La revisión visual y las dos revisiones independientes detectaron tres defectos que las pruebas no cubrían | ADR 0007 redactado por la IA, con las desviaciones y los recortes de alcance declarados | Pruebas escritas antes que el código; un catálogo aplica las mismas comprobaciones de accesibilidad a cada componente |
| 3. Plataforma | | | | |
| 4. Acceso | | | | |
| 5. Cuentas y movimientos | | | | |
| 6. Inicio dinámico | | | | |
| 7. Consola web | | | | |
| 8. Transferencias | | | | |
| 9. Notificaciones | | | | |
| 10. Servicios | | | | |
| 11. Cierre | | | | |
