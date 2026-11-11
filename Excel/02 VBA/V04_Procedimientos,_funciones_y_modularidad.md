# V04 — Procedimientos, funciones y modularidad

**Curso integral de VBA · 2026 · Módulo V04/V15**

**Propósito:** aprender procedimientos, funciones y modularidad mediante teoría, programación, pruebas y un proyecto verificable.

**Temario de trabajo:** Sub, Function, argumentos ByVal/ByRef, ámbito, retorno, diseño modular. Los títulos son una propuesta de secuencia didáctica para esta entrega; deben cotejarse con el desglose literal del roadmap original.

## Contexto actualizado (noviembre de 2026)

VBA continúa disponible en las aplicaciones de escritorio compatibles de Microsoft Office, incluyendo Excel Windows y Mac. No se ejecuta en Excel web. Las macros pueden ser bloqueadas por la política de seguridad y las de origen de Internet suelen estar restringidas. ActiveX es tecnología heredada, deshabilitada por defecto en Microsoft 365/Office 2024, y no funciona en Mac. Para flujos multiplataforma considerar Office Scripts.

| Área | Windows | macOS |
|---|---|---|
| Excel VBA | Compatible | Compatible, con diferencias de objetos |
| COM/ActiveX | COM de Windows; ActiveX heredado y restringido | COM/ActiveX de Windows no disponibles |
| Sistema de archivos | Rutas Windows y permisos de usuario | Sandbox, autorizaciones y rutas Mac |
| Automatización externa | COM, bibliotecas Windows, APIs con permisos | AppleScriptTask y APIs compatibles |
| Declaraciones de APIs | PtrSafe/LongPtr según arquitectura | No reutilizar llamadas Win32 |
| Excel web | VBA no ejecutable | VBA no ejecutable |

**Seguridad:** nunca habilitar todas las macros indiscriminadamente; trabajar con archivos de confianza, revisar código, limitar permisos y no incrustar secretos.

## Objetivos

1. Comprender los fundamentos y términos de este módulo.
2. Escribir y explicar una macro o procedimiento reproducible.
3. Identificar diferencias entre Windows y Mac.
4. Implementar manejo de errores y pruebas.
5. Documentar decisiones y límites de compatibilidad.

## V04.01 — Sub

**Concepto.** Este bloque estudia **Sub** en el contexto de automatización de Excel. Debe distinguirse el dato de entrada, el objeto o instrucción de VBA, los efectos secundarios y el resultado observable. Un código correcto no solo produce un valor: también debe comportarse adecuadamente con entradas vacías, libros protegidos, hojas inexistentes y errores de usuario.

**Procedimiento guiado.** (1) Crea un libro de prueba `.xlsm` y una hoja `Datos`. (2) Abre el Editor de Visual Basic desde la pestaña Programador/Developer o el menú disponible. (3) Escribe un procedimiento pequeño. (4) Ejecuta con datos ficticios. (5) Inspecciona resultados y registra un caso negativo. (6) Guarda una versión del código `.bas` cuando corresponda.

**Prueba de calidad.** Antes de publicar, verifica qué sucede si la hoja falta, si el archivo no está guardado, si no existe permiso o si el código se ejecuta por segunda vez.

**Windows vs Mac.** La sintaxis básica de VBA y el modelo de objetos de Excel suelen ser similares, pero evita suponer que los componentes COM, ActiveX, rutas o llamadas Win32 funcionan en macOS. Usa `#If Mac Then` para aislar código específico cuando corresponda.

## V04.02 — Function

**Concepto.** Este bloque estudia **Function** en el contexto de automatización de Excel. Debe distinguirse el dato de entrada, el objeto o instrucción de VBA, los efectos secundarios y el resultado observable. Un código correcto no solo produce un valor: también debe comportarse adecuadamente con entradas vacías, libros protegidos, hojas inexistentes y errores de usuario.

**Procedimiento guiado.** (1) Crea un libro de prueba `.xlsm` y una hoja `Datos`. (2) Abre el Editor de Visual Basic desde la pestaña Programador/Developer o el menú disponible. (3) Escribe un procedimiento pequeño. (4) Ejecuta con datos ficticios. (5) Inspecciona resultados y registra un caso negativo. (6) Guarda una versión del código `.bas` cuando corresponda.

**Prueba de calidad.** Antes de publicar, verifica qué sucede si la hoja falta, si el archivo no está guardado, si no existe permiso o si el código se ejecuta por segunda vez.

**Windows vs Mac.** La sintaxis básica de VBA y el modelo de objetos de Excel suelen ser similares, pero evita suponer que los componentes COM, ActiveX, rutas o llamadas Win32 funcionan en macOS. Usa `#If Mac Then` para aislar código específico cuando corresponda.

## V04.03 — Argumentos byval/byref

**Concepto.** Este bloque estudia **argumentos ByVal/ByRef** en el contexto de automatización de Excel. Debe distinguirse el dato de entrada, el objeto o instrucción de VBA, los efectos secundarios y el resultado observable. Un código correcto no solo produce un valor: también debe comportarse adecuadamente con entradas vacías, libros protegidos, hojas inexistentes y errores de usuario.

**Procedimiento guiado.** (1) Crea un libro de prueba `.xlsm` y una hoja `Datos`. (2) Abre el Editor de Visual Basic desde la pestaña Programador/Developer o el menú disponible. (3) Escribe un procedimiento pequeño. (4) Ejecuta con datos ficticios. (5) Inspecciona resultados y registra un caso negativo. (6) Guarda una versión del código `.bas` cuando corresponda.

**Prueba de calidad.** Antes de publicar, verifica qué sucede si la hoja falta, si el archivo no está guardado, si no existe permiso o si el código se ejecuta por segunda vez.

**Windows vs Mac.** La sintaxis básica de VBA y el modelo de objetos de Excel suelen ser similares, pero evita suponer que los componentes COM, ActiveX, rutas o llamadas Win32 funcionan en macOS. Usa `#If Mac Then` para aislar código específico cuando corresponda.

## V04.04 — Ámbito

**Concepto.** Este bloque estudia **ámbito** en el contexto de automatización de Excel. Debe distinguirse el dato de entrada, el objeto o instrucción de VBA, los efectos secundarios y el resultado observable. Un código correcto no solo produce un valor: también debe comportarse adecuadamente con entradas vacías, libros protegidos, hojas inexistentes y errores de usuario.

**Procedimiento guiado.** (1) Crea un libro de prueba `.xlsm` y una hoja `Datos`. (2) Abre el Editor de Visual Basic desde la pestaña Programador/Developer o el menú disponible. (3) Escribe un procedimiento pequeño. (4) Ejecuta con datos ficticios. (5) Inspecciona resultados y registra un caso negativo. (6) Guarda una versión del código `.bas` cuando corresponda.

**Prueba de calidad.** Antes de publicar, verifica qué sucede si la hoja falta, si el archivo no está guardado, si no existe permiso o si el código se ejecuta por segunda vez.

**Windows vs Mac.** La sintaxis básica de VBA y el modelo de objetos de Excel suelen ser similares, pero evita suponer que los componentes COM, ActiveX, rutas o llamadas Win32 funcionan en macOS. Usa `#If Mac Then` para aislar código específico cuando corresponda.

## V04.05 — Retorno

**Concepto.** Este bloque estudia **retorno** en el contexto de automatización de Excel. Debe distinguirse el dato de entrada, el objeto o instrucción de VBA, los efectos secundarios y el resultado observable. Un código correcto no solo produce un valor: también debe comportarse adecuadamente con entradas vacías, libros protegidos, hojas inexistentes y errores de usuario.

**Procedimiento guiado.** (1) Crea un libro de prueba `.xlsm` y una hoja `Datos`. (2) Abre el Editor de Visual Basic desde la pestaña Programador/Developer o el menú disponible. (3) Escribe un procedimiento pequeño. (4) Ejecuta con datos ficticios. (5) Inspecciona resultados y registra un caso negativo. (6) Guarda una versión del código `.bas` cuando corresponda.

**Prueba de calidad.** Antes de publicar, verifica qué sucede si la hoja falta, si el archivo no está guardado, si no existe permiso o si el código se ejecuta por segunda vez.

**Windows vs Mac.** La sintaxis básica de VBA y el modelo de objetos de Excel suelen ser similares, pero evita suponer que los componentes COM, ActiveX, rutas o llamadas Win32 funcionan en macOS. Usa `#If Mac Then` para aislar código específico cuando corresponda.

## V04.06 — Diseño modular

**Concepto.** Este bloque estudia **diseño modular** en el contexto de automatización de Excel. Debe distinguirse el dato de entrada, el objeto o instrucción de VBA, los efectos secundarios y el resultado observable. Un código correcto no solo produce un valor: también debe comportarse adecuadamente con entradas vacías, libros protegidos, hojas inexistentes y errores de usuario.

**Procedimiento guiado.** (1) Crea un libro de prueba `.xlsm` y una hoja `Datos`. (2) Abre el Editor de Visual Basic desde la pestaña Programador/Developer o el menú disponible. (3) Escribe un procedimiento pequeño. (4) Ejecuta con datos ficticios. (5) Inspecciona resultados y registra un caso negativo. (6) Guarda una versión del código `.bas` cuando corresponda.

**Prueba de calidad.** Antes de publicar, verifica qué sucede si la hoja falta, si el archivo no está guardado, si no existe permiso o si el código se ejecuta por segunda vez.

**Windows vs Mac.** La sintaxis básica de VBA y el modelo de objetos de Excel suelen ser similares, pero evita suponer que los componentes COM, ActiveX, rutas o llamadas Win32 funcionan en macOS. Usa `#If Mac Then` para aislar código específico cuando corresponda.

## Código de referencia

```vb
Function Importe(ByVal unidades As Double, ByVal precio As Double) As Double
    Importe = unidades * precio
End Function
```

**Cómo practicar:** escribe el código en un módulo estándar, salvo procedimientos `Worksheet_Change`, que deben ir en el módulo de la hoja correspondiente. `ValidarEntradas` y `GenerarReporte` del V15 son dependencias ilustrativas que debes implementar antes de ejecutar el procedimiento principal. No ejecutes macros recibidas de fuentes desconocidas.

## Caso empresarial guiado

**Escenario:** un equipo registra ventas con `ID`, `Fecha`, `Región`, `Cantidad`, `Precio`. Debe calcular el importe, validar que las cantidades sean positivas, generar un reporte y registrar la fecha de procesamiento.

**Datos de control:** V01: 3 × 400 = 1200; V02: 4 × 200 = 800; V03: 1 × 2500 = 2500. **Total: 4500 MXN; unidades: 8; filas: 3.**

**Arquitectura:** datos originales → validación → transformación → reporte → auditoría. El código no debe alterar silenciosamente los registros originales.

```mermaid
flowchart LR
 A[Datos] --> B[Validación]
 B --> C[Procedimiento VBA]
 C --> D[Reporte]
 D --> E[Pruebas y auditoría]
```

### Laboratorio 1 — Sub

1. Prepara un libro de prueba con los tres registros.
2. Implementa una rutina que inspeccione o transforme una parte del flujo.
3. Prueba el caso positivo (total 4500).
4. Prueba el caso negativo (cantidad vacía, hoja inexistente o permiso denegado).
5. Documenta qué cambió en Windows y qué verificarías en Mac.

**Criterio de aceptación:** resultado correcto, mensaje de error comprensible, ningún dato original perdido y ejecución repetible.

### Laboratorio 2 — Function

1. Prepara un libro de prueba con los tres registros.
2. Implementa una rutina que inspeccione o transforme una parte del flujo.
3. Prueba el caso positivo (total 4500).
4. Prueba el caso negativo (cantidad vacía, hoja inexistente o permiso denegado).
5. Documenta qué cambió en Windows y qué verificarías en Mac.

**Criterio de aceptación:** resultado correcto, mensaje de error comprensible, ningún dato original perdido y ejecución repetible.

### Laboratorio 3 — argumentos ByVal/ByRef

1. Prepara un libro de prueba con los tres registros.
2. Implementa una rutina que inspeccione o transforme una parte del flujo.
3. Prueba el caso positivo (total 4500).
4. Prueba el caso negativo (cantidad vacía, hoja inexistente o permiso denegado).
5. Documenta qué cambió en Windows y qué verificarías en Mac.

**Criterio de aceptación:** resultado correcto, mensaje de error comprensible, ningún dato original perdido y ejecución repetible.

### Laboratorio 4 — ámbito

1. Prepara un libro de prueba con los tres registros.
2. Implementa una rutina que inspeccione o transforme una parte del flujo.
3. Prueba el caso positivo (total 4500).
4. Prueba el caso negativo (cantidad vacía, hoja inexistente o permiso denegado).
5. Documenta qué cambió en Windows y qué verificarías en Mac.

**Criterio de aceptación:** resultado correcto, mensaje de error comprensible, ningún dato original perdido y ejecución repetible.

### Laboratorio 5 — retorno

1. Prepara un libro de prueba con los tres registros.
2. Implementa una rutina que inspeccione o transforme una parte del flujo.
3. Prueba el caso positivo (total 4500).
4. Prueba el caso negativo (cantidad vacía, hoja inexistente o permiso denegado).
5. Documenta qué cambió en Windows y qué verificarías en Mac.

**Criterio de aceptación:** resultado correcto, mensaje de error comprensible, ningún dato original perdido y ejecución repetible.

## Ejercicios (15)

### E01

Define el objetivo de esta tecnología y menciona dos casos de uso.

### E02

Distingue procedimiento Sub y Function.

### E03

Explica por qué `Option Explicit` ayuda a prevenir errores.

### E04

Identifica qué hace `ThisWorkbook`.

### E05

¿Por qué conviene calificar `Worksheets` con el libro?

### E06

¿Cuál es el resultado de 3 × 400 + 4 × 200 + 1 × 2500?

### E07

¿Cómo detectas una hoja inexistente?

### E08

¿Qué riesgo hay en ejecutar dos veces una macro que añade filas?

### E09

¿Qué significa `On Error GoTo`?

### E10

¿Por qué no se deben incrustar tokens o contraseñas?

### E11

¿Funciona COM de Windows en Excel Mac?

### E12

¿Qué mecanismo ofrece macOS para ciertos scripts externos?

### E13

¿Qué diferencia hay entre VBA y Office Scripts?

### E14

¿Por qué ActiveX no es una elección recomendable para un proyecto nuevo?

### E15

Diseña tres pruebas de aceptación para una macro empresarial.

## Solucionario (separado de enunciados)

### Solución E01

Automatiza tareas de Office; por ejemplo, generar reportes y validar datos.

### Solución E02

Sub realiza acciones; Function devuelve un valor mediante su nombre.

### Solución E03

Exige declarar variables y ayuda a detectar errores tipográficos.

### Solución E04

Referencia el libro que contiene el código VBA.

### Solución E05

Evita actuar sobre un libro activo distinto del esperado.

### Solución E06

4500 MXN.

### Solución E07

Comprobar existencia antes de usarla o manejar el error con una rutina controlada.

### Solución E08

Puede duplicar registros; diseñar idempotencia o detección de duplicados.

### Solución E09

Transfiere control a una etiqueta de manejo de errores ante errores de ejecución.

### Solución E10

Pueden filtrarse a usuarios con acceso al archivo o al proyecto VBA.

### Solución E11

No; requiere alternativa compatible.

### Solución E12

AppleScriptTask, sujeto a permisos y ubicación del script.

### Solución E13

VBA está orientado al escritorio; Office Scripts utiliza TypeScript y admite escenarios web y flujos compatibles.

### Solución E14

Es heredado, está deshabilitado por defecto en versiones recientes y no funciona en Mac.

### Solución E15

Validar importes, entrada inválida y repetición segura de la ejecución.

## Proyecto integrador del módulo: Procedimientos, funciones y modularidad

**Entregables:** libro `.xlsm` de práctica, código fuente `.bas`/`.cls` cuando corresponda, README con requisitos, captura o transcripción de pruebas y matriz de compatibilidad Windows/Mac.

**Pruebas:** exactitud del total 4500, integridad de 3 registros, tratamiento de errores, idempotencia cuando sea necesaria y ejecución en entorno autorizado.

**Rúbrica:** funcionalidad 30 puntos; pruebas 25; arquitectura y claridad 20; seguridad 15; compatibilidad/documentación 10.

**Evaluación final:** explicar 5 decisiones técnicas, implementar 1 macro funcional, registrar 2 casos negativos y describir qué cambiaría para ejecutarla en Mac.

## Referencias oficiales (consultadas en noviembre de 2026)

- [VBA Excel object model](https://learn.microsoft.com/en-us/office/vba/api/overview/excel)
- [Office for Mac VBA](https://learn.microsoft.com/en-us/office/vba/api/overview/office-mac)
- [VBA 64-bit](https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/64-bit-visual-basic-for-applications-overview)
- [AppleScriptTask](https://learn.microsoft.com/en-us/office/vba/office-mac/applescripttask)
- [Macro security](https://support.microsoft.com/en-us/office/vba/enable-or-disable-macros-in-microsoft-365-files)
- [ActiveX](https://support.microsoft.com/en-us/excel/add-or-register-an-activex-control)
- [Office Scripts vs VBA](https://learn.microsoft.com/en-us/office/dev/scripts/resources/vba-differences)
- [Office for Mac updates](https://learn.microsoft.com/officeupdates/update-history-office-for-mac)

**Límites de verificación:** el material se ha preparado a partir de documentación de Microsoft, pero no se ejecutaron macros en Excel Windows ni Mac en este entorno. Algunas funciones dependen de edición, licencia, políticas y actualización de Office.
