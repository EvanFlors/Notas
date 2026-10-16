# Example 01 — Netflix "paved road": resumen anotado

> Ejemplo de **lectura y análisis**. No se ejecuta nada.

## Qué leer

- Charlas e ingeniería pública de Netflix sobre *paved road* y *full-cycle developers*.
- Blog post **"Full Cycle Developers at Netflix"** (Netflix Tech Blog, 2018).
- Charlas de *platform engineering* internas de Netflix (QCon, SREcon).

Enlaces en `../../resources/links.md`.

## Idea central del modelo

Netflix opera con **centenares** de microservicios en AWS. En vez de forzar un stack único, propone un **paved road** por caso de uso: el camino que el platform team opera **en nombre del developer**.

Si vas por el paved road:

- El platform team te ofrece runtime (Titus para contenedores, Spinnaker para deploy, Atlas para métricas, Mantis para streaming, etc.).
- Upgrades, parches, seguridad: los hace el platform team.
- Soporte 24/7 con SLA interno.

Si vas **off road**:

- Puedes hacerlo. Nadie te lo impide.
- Pero asumes **tú** on-call, upgrades, migraciones, seguridad.
- El platform team sigue siendo buen vecino, pero sin SLA.

## Qué transferir a una organización de 50–500 ingenieros

| Concepto | Transferible | Comentario |
|----------|--------------|------------|
| Asimetría on/off road | **Sí** | El motor cultural. Hace la convergencia natural. |
| Operación "en nombre de" | **Parcialmente** | Netflix tiene equipos grandes. En menor escala, "operación compartida" es más realista. |
| Full-cycle developer | **Depende** | Funciona si el platform team es realmente *X-as-a-Service* (ver `plat-01`). Si no, se degrada en "DevOps sin herramientas". |
| Stack 100 % propio (Spinnaker, Titus, Atlas) | **No** | Ni el presupuesto ni la justificación. Usa OSS/SaaS. |
| Métricas + feedback explícito | **Sí** | Es casi gratis y evita el "paved road en papel". |

## Trampa clásica al copiar Netflix

Copiar el *vocabulario* ("paved road", "full cycle") **sin** el fondo:

- Decir "tenemos paved road" cuando lo que hay es un README en Confluence.
- Decir "full cycle developer" como excusa para que los equipos de producto **también** operen la plataforma.

El paved road de Netflix funciona porque **el platform team realmente opera infraestructura compartida**. Sin ese compromiso, el término es decoración.

## Preguntas de análisis

1. ¿Qué parte del paved road de Netflix es **cultural** y qué parte es **tecnológica**? ¿Cuál copiarías primero?
2. Si tu platform team son **3 personas**, ¿qué recortas del modelo para que sea sostenible?
3. ¿Cómo medirías "adopción" del paved road sin inflar la métrica?
4. Un equipo de producto quiere ir off-road. ¿Lo apoyas, lo bloqueas o lo acompañas? ¿Con qué criterio?
