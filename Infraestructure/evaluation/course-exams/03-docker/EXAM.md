# Examen de certificación — Curso **Docker**

- **Nivel evaluado:** intermedio-avanzado (módulos `dkr-06` a `dkr-14`, con prerrequisitos de `dkr-01` a `dkr-05`).
- **Duración:** 90–120 min.
- **Umbral de aprobación:** 70% ponderado.
- **Dimensiones evaluadas:** conceptual + operativa + arquitectónica (`todas`).
- **Entorno:** 100% local. Requiere `docker` (≥ 24.x con BuildKit por defecto), `docker buildx`, `syft`, `trivy`, `cosign` y acceso a un *registry* local (`registry:2` en contenedor). **No se requieren credenciales de cloud ni acceso a Internet para registries privados.** No incluir ningún secreto real: los ejercicios usan tokens dummy generados localmente.
- **Idioma:** enunciados en español, código/comandos/artefactos en inglés.
- **Entrega:** carpeta comprimida con el `starter/` resuelto + respuestas en `answers.md` + `ADR-001-base-image-and-supply-chain.md`.

> **Reglas de integridad.** Puedes consultar `man`, `docker --help` y páginas oficiales. **No** puedes pedir ayuda a un LLM durante la parte operativa; sí puedes consultarlo para verificar tu teoría previa a responder (indícalo en `answers.md`).

---

## Distribución del puntaje

| Parte | Dimensión | Peso |
|-------|-----------|------|
| Preguntas conceptuales (Q1–Q11) | conceptual | 35% |
| Ejercicio operativo (`operative/`) | operativa | 40% |
| Ejercicio arquitectónico (`architectural/`) | arquitectónica | 25% |

Un examen con < 50% en cualquiera de las tres dimensiones es **no aprobado** aunque el ponderado supere 70%.

---

## Parte 1 — Preguntas conceptuales (35%)

Formato: respuesta corta/explicación. Evitar listas de bullets vacíos; se busca **razonamiento**. Longitud sugerida: 4–10 líneas por respuesta.

### Q1 (C1) — Namespaces vs cgroups

> Un compañero afirma: *"los contenedores son procesos aislados por cgroups"*. Corrige la afirmación explicando qué rol juega cada primitiva (namespaces, cgroups, overlayfs) y qué pasaría si tuvieras namespaces sin cgroups (y viceversa).

### Q2 (C1) — VM vs contenedor

> ¿Por qué un kernel panic dentro de un contenedor afecta al host pero un kernel panic dentro de una VM no? Relaciónalo con la decisión arquitectónica de "compartir kernel".

### Q3 (C2) — ENTRYPOINT y señales

> Tienes:
>
> ```dockerfile
> ENTRYPOINT python app.py
> ```
>
> El equipo reporta que al hacer `docker stop <c>` el contenedor tarda **10 segundos** en terminar. Explica **por qué** y propón **dos** correcciones distintas (una a nivel Dockerfile, otra a nivel runtime). Diferencia explícitamente *forma shell vs forma exec*.

### Q4 (C4) — Secretos de build

> Dado:
>
> ```dockerfile
> ARG GITHUB_TOKEN
> RUN git clone https://x-access-token:${GITHUB_TOKEN}@github.com/acme/private.git
> ```
>
> Un auditor dice: *"está bien, el ARG no persiste en runtime"*. ¿Tiene razón? Explica qué comando revelaría el problema y describe la alternativa correcta con BuildKit, incluyendo cómo se consume el secreto desde el `RUN`.

### Q5 (C5) — Compose en producción

> El equipo propone deployar producción con `docker compose up -d` en una VM EC2. Enumera **tres garantías** que un orquestador (Kubernetes/Nomad/ECS) ofrece y Compose **no**, y explica qué significa realmente `depends_on: condition: service_healthy` (y qué no significa).

### Q6 (C6) — Tags vs digests

> Un pipeline hace `docker pull app:v1.2.3` en cada deploy. Un release antiguo (que funcionaba) ahora falla en producción tras un rebuild. ¿Cómo es posible si el tag no cambió? Describe el mecanismo y la mitigación concreta (sintaxis incluida) a aplicar en el `Deployment` / `Dockerfile base`.

### Q7 (C7) — Privileged containers

> Explica qué **cambia** cuando corres `docker run --privileged` respecto al default. En particular: ¿qué capabilities se añaden, qué filtros se desactivan y por qué sigue sin ser *literalmente* lo mismo que ejecutar un proceso en el host? ¿Cuándo sí es defendible usarlo?

### Q8 (C8) — Base image trade-offs

> Tu app es FastAPI con `psycopg2-binary`, `cryptography` y `numpy`. Un ingeniero propone migrar de `python:3.12-slim` a `python:3.12-alpine` *"para ahorrar MB"*. ¿Qué riesgos técnicos específicos tiene esa migración? Compara brevemente contra `gcr.io/distroless/python3` y Chainguard `python`, señalando para cada opción un escenario donde **sí** sería la correcta.

### Q9 (C9) — Auditoría de `docker run`

> Audita este comando y señala **todos** los problemas de seguridad, ordenados por severidad, con una línea de justificación por cada uno:
>
> ```bash
> docker run -d --name api \
>   -p 80:8000 \
>   -v /var/run/docker.sock:/var/run/docker.sock \
>   -v /:/host \
>   --privileged \
>   -e DB_PASSWORD=hunter2 \
>   acme/api:latest
> ```

### Q10 (C11) — Multi-arch y reproducibilidad

> Explica qué es realmente una imagen *multi-arch* a nivel de registry (qué objeto describe `docker buildx imagetools inspect`). Luego: dos equipos buildean el mismo commit con el mismo Dockerfile y obtienen digests distintos. Enumera **cuatro** fuentes probables de la divergencia.

### Q11 (C12) — docker.sock

> Explica por qué montar `/var/run/docker.sock` dentro de un contenedor no-privileged es, en la práctica, equivalente a dar `root` sobre el host. Describe la cadena de ataque en 3–4 pasos concretos.

---

## Parte 2 — Ejercicio operativo (40%)

Ver `operative/README.md`. Siete tareas secuenciales sobre una app FastAPI, un `Dockerfile` deficiente y un `compose.yaml` inseguro que debes **corregir, endurecer y firmar**. Validación automatizada vía `operative/validate.sh`.

**Entregables:**

1. `operative/solution/Dockerfile` (multi-stage, BuildKit, cache + secret mount, USER no-root, basado en distroless o chainguard).
2. `operative/solution/compose.yaml` corregido.
3. `operative/solution/sbom.cdx.json` (CycloneDX).
4. `operative/solution/trivy-report.json`.
5. `operative/solution/cosign.pub` + firma + attestation adjuntas en el registry local.
6. `operative/solution/notes.md` con la justificación de cada decisión y la salida de `docker history --no-trunc`.
7. Ejecución exitosa de `operative/validate.sh` (log pegado).

---

## Parte 3 — Ejercicio arquitectónico (25%)

Ver `architectural/scenario.md`. Debes producir un **ADR** (`architectural/ADR-001-base-image-and-supply-chain.md`) justificando elección de base image, estrategia de tagging/pinning, flujo de supply chain (SBOM, firma, verificación) y plan multi-arch, para un escenario con restricciones específicas (producción air-gapped, 10 microservicios Python, requisito de atestación SLSA).

---

## Rúbrica global

Cada ítem se puntúa en una escala de 0–3 según los descriptores de la **guía de corrección** (`operative/VALIDATION.md` para operativa, descriptor por criterio en `architectural/scenario.md` para arquitectónica).

| Nivel | Puntaje | Descriptor general |
|-------|---------|--------------------|
| Insuficiente | 0 | Omitido, incorrecto o con red flag presente. |
| Básico | 1 | Reconoce el concepto pero lo aplica mecánicamente; sin razonamiento o con error relevante. |
| Competente | 2 | Correcto, justificado, trade-offs mencionados. |
| Experto | 3 | Correcto + anticipa modos de falla + propone verificación + conecta con otras capas (CI, orquestador, registry). |

**Umbral:** 70% ponderado **y** ≥ 50% por dimensión **y** 0 red flags activas (ver `competency-matrix.yaml`). Red flag activa ⇒ rebaja de 1 nivel al criterio donde aparezca; dos o más ⇒ no aprobado.

---

## Preguntas de seguimiento (sólo instructor, modalidad live)

Si el examen se corrige en modalidad live, el instructor puede escoger 2–3 de estas para distinguir memorización de comprensión:

1. "Enséñame con `/proc/<pid>/ns/*` que dos contenedores comparten o no el net namespace." (sobre Q1/Q7)
2. "Modifica tu `Dockerfile` para romper la caché del paso de dependencias cambiando un comentario del código y mídelo." (sobre OP-task-1)
3. "Si borro la clave privada con la que firmaste, ¿puedo seguir verificando? ¿Y rotar?" (sobre OP-task-6 / cosign keyless)
4. "Un atacante publica una imagen con el mismo tag en el registry. ¿Qué verificación lo detecta y por qué?" (sobre Q6 / C10)
5. "Convierte tu `--cap-drop=ALL --cap-add=NET_BIND_SERVICE` en innecesario cambiando algo del contenedor." (sobre OP-task-5)

Ver `operative/VALIDATION.md` para el guión completo de corrección.
