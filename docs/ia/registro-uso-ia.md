# Uso de IA en el desarrollo

Resumen de cómo se usaron herramientas de IA en este reto y qué impacto tuvieron en productividad, calidad, documentación y pruebas.

## Herramientas

| Herramienta | Uso |
|---|---|
| Modelo generativo de diseño | Pantallas y sistema de diseño a partir de un encargo escrito |
| Asistente de programación con IA, usado desde la terminal | Análisis del enunciado, propuestas de arquitectura, revisión de diseños, código, pruebas y documentación |

## Cómo se trabajó

El autor dirigió y decidió; la IA propuso y ejecutó. El código, las pruebas y la documentación los generó el asistente bajo la dirección del autor, que definió la arquitectura, el alcance y qué se publicaba.

El trabajo se organizó en once etapas verticales. Cada una siguió el mismo ciclo:

1. El autor aprueba el alcance y las decisiones de la etapa.
2. El asistente la construye en commits pequeños, verificados antes de integrarse.
3. Una revisión independiente, hecha por una instancia sin el contexto de quien escribió el código, busca defectos.
4. Lo encontrado se reproduce con una prueba que falla y después se corrige.
5. Cuando hay un dispositivo disponible, la etapa se comprueba en él antes de publicarla.

## Diseño

Fue el primer uso de la IA y el que fijó el aspecto del producto.

- El encargo de diseño se redactó a partir del enunciado y de la paleta pública del banco, y un modelo generativo produjo las pantallas, los tokens y la consola.
- El análisis del encargo detectó que el naranja de marca con texto blanco da un contraste de 2.5:1, por debajo del mínimo de 4.5:1. De ahí salió la regla de texto oscuro sobre naranja, que hoy protege una prueba.
- El resultado se revisó dos veces contra el enunciado. La primera revisión produjo una lista de 45 correcciones; la segunda comprobó cada una contra las pantallas y los archivos, no contra lo que el modelo declaraba.
- Los tokens del diseño son la referencia del código: una prueba falla si un valor se desvía.

## Decisiones del autor

- Bloc como gestión de estado.
- Next.js para la consola, frente a la propuesta inicial de Flutter Web.
- Una consola propia, en lugar de usar solo la de Firebase.
- Documentación en español; código y commits en inglés.
- Publicar la demostración, y hacerlo en Firebase App Hosting para que no exista ninguna clave de servidor.
- Dos refinamientos tras usar el producto desplegado: una pantalla con todos los movimientos y la consola dividida en secciones.

## Impacto

**Productividad.** El alcance construido (aplicación con ocho paquetes, consola, API de clientes, reglas y documentación) no habría cabido en el plazo de otro modo. El límite no fue la velocidad de escritura sino la verificación.

**Calidad.** Lo que más defectos evitó fueron las revisiones independientes. Encontraron, entre otros, datos del cliente que quedaban en el dispositivo tras cerrar sesión, una transferencia que podía quedar en cola después de haberse enviado y un teléfono compartido que habría recibido avisos del cliente anterior. Ejecutar en un dispositivo encontró lo que las pruebas no veían, como un campo de contraseña anunciado como botón a los lectores de pantalla.

**Documentación.** Las decisiones se escribieron al tomarse, con sus alternativas descartadas. Cada documento separa lo visto en un dispositivo, lo cubierto solo por pruebas y lo que no se verificó.

**Pruebas.** Las suites corren en cada push; los totales están en el [README](../../README.md). Donde la prueba se escribió antes que el código, las revisiones encontraron menos; donde se escribió a la vez, encontraron más defectos de ciclo de vida.

## Límites

- La IA se equivocó y hubo que corregirla: afirmó algo sobre las claves de Firebase antes de comprobarlo, dio por bueno un commit que no compilaba aislado y, al integrar tres etapas, siguió adelante tras una sustitución de texto fallida. Los tres casos se detectaron al verificar y se repararon antes de publicar.
- La prueba primero no se siguió siempre en la primera versión de cada etapa.
- Lo que sigue sin verificar está en [alcance y riesgos](../alcance-y-riesgos.md).

## Qué se haría distinto

- Exigir la prueba primero desde la primera versión de cada etapa.
- Llevar cada etapa a un dispositivo antes de darla por cerrada.
- Tener el modo local con emuladores desde el principio, para correr el flujo de extremo a extremo en la integración continua.
