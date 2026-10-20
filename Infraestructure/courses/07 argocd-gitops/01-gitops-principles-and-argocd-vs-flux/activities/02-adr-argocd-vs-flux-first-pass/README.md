# Actividad 02 — ADR corto: primera elección Argo CD vs Flux

## 1. Identificación

- **ID:** `argo-01-02-adr-argocd-vs-flux-first-pass`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `argo-01-gitops-principles-and-argocd-vs-flux`
- **Dificultad:** beginner
- **Duración estimada:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Argo CD y Flux son ambos **implementaciones legítimas** de GitOps, maduras, graduadas en CNCF, con comunidades activas. Elegir uno **por features** es engañarse: las features convergen. La elección real es **filosófica y organizacional**: UX con UI vs kubectl-only, equipo de app vs equipo de plataforma, cultura de PR vs cultura de operación interactiva, multi-cluster desde día 1 vs un cluster por mucho tiempo.

Esta actividad entrena ese músculo: **defender razonadamente una elección** para una organización dada, con los criterios por delante y las features por detrás. El entregable es un **ADR** (Architecture Decision Record) corto en Markdown, con el formato estándar: Contexto / Decisión / Consecuencias / Alternativas descartadas.

No se requiere cluster, ni Argo CD, ni Flux. Es puramente conceptual y de criterio.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Articular **cuándo** Argo CD encaja mejor y cuándo Flux encaja mejor, con criterios **medibles** (tamaño del equipo, cultura de operación, requisitos de UX, estado del tooling).
- Nombrar **al menos 5 criterios** concretos para decidir entre los dos.
- Reconocer el **antipatrón** "elegir por feature-table" y argumentar por qué es débil.
- Escribir un ADR corto y defendible.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (especialmente §4.5, §8.2 y §9.5).
- Haber recorrido `examples/01-push-vs-pull-diagram/` y `examples/02-opengitops-principles-walkthrough/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/argo-01-adr
cd /tmp/argo-01-adr
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/argo-01-adr`.)

### 5.2 Escenario (ficticio pero realista)

> **"Fintech Nórdica" (ficticia)**. Empresa de 180 personas, 40 desarrolladores backend, 20 frontend, un equipo de **plataforma de 3 personas** (reciente). Producto: una app de banca para negocios en 4 países. Stack: ~25 microservicios en Go/Java, cada uno con su propio chart Helm, desplegados hoy desde Jenkins (`helm upgrade --install` desde pipelines con kubeconfig). Infraestructura: 2 clusters GKE (prod + stg) + 1 cluster dev. El equipo de plataforma recibe el mandato de **migrar a GitOps**: cortar el acceso directo del CI al cluster, eliminar drift silencioso, mejorar auditoría para la próxima auditoría regulatoria PSD2.
>
> Debate interno:
>
> - El **lead de plataforma** viene de Flux v1 en su empleo anterior, le gusta la filosofía modular y "kubectl-only". Argumenta que la UI de Argo CD "invita a tocar en caliente".
> - El **head of engineering** de backend prefiere Argo CD: "los desarrolladores quieren ver qué está desplegado y qué está sincronizado sin pedirlo al equipo de plataforma; una UI reduce tickets".
> - El **ingeniero de release** quiere **image automation nativo** porque hoy en Jenkins hay 25 jobs manuales de bump de tag; cualquier opción que requiera un add-on separado "duplica el problema".
> - El **CISO** quiere que todo cambio pase por PR explícito; no quiere "clicks en una UI que cambien prod". Pero sí quiere que haya alguna forma de **ver el estado** para auditoría.
>
> Tu tarea: escribir un ADR corto argumentando **qué eligen**: **Argo CD** o **Flux** (o combinación). Puede ser cualquiera — lo que importa es el razonamiento. (El ADR de referencia argumenta "Argo CD con sync automático y UI de solo lectura para desarrolladores" para calibrar, pero una defensa sólida de Flux es igual de válida.)

### 5.3 Entregable: `ADR.md`

Produce un archivo `ADR.md` con **cuatro secciones** explícitas (estilo ADR estándar):

#### A. Contexto

Describe en 5–10 líneas el escenario (puedes copiarlo y resumirlo). Incluye explícitamente:

- Tamaño del equipo de plataforma vs equipo de desarrollo.
- Número de clusters y entornos.
- Estado actual (Jenkins + `helm upgrade --install` → push).
- Driver regulatorio (PSD2 / auditoría).
- Las 4 posturas internas (plataforma, head of eng, release, CISO).

#### B. Decisión

Enuncia **claramente** qué recomiendas y una frase que lo resuma. Formato:

```
Elegimos Argo CD como motor GitOps principal. Configuramos
sync automatico con selfHeal en dev y stg; en prod sync
automatico con PR explicito para cambios criticos. UI expuesta
en modo solo-lectura para desarrolladores via SSO. Image
automation vía argocd-image-updater como add-on; revisaremos
en 6 meses contra Flux image automation si fricciona.
```

(Si prefieres defender "Flux", es válido — pero el ADR tendrá que mostrar cómo resolver la demanda de visibilidad para los 60 desarrolladores sin UI de edición.)

#### C. Consecuencias y disparadores

Dos sub-partes:

- **Consecuencias de la decisión**: qué ganas y qué pierdes. Qué fricciones nuevas aparecen (p. ej. si eliges Argo CD: UI que operar y endurecer, SSO que integrar, add-on separado para image automation). Qué beneficios directos (p. ej. visibilidad para 60 developers sin tickets a plataforma).
- **Disparadores (triggers) para reconsiderar la decisión**: lista de condiciones **concretas y medibles** que, si se cumplen, obligarían a revisar la elección. Al menos **5**:
  - Equipo de plataforma crece/decrece a X.
  - Número de clusters supera N.
  - La UI genera incidentes recurrentes de "click en caliente".
  - Image automation con add-on separado se vuelve inmantenible.
  - Requisito regulatorio nuevo que exija "sin UI de escritura".
  - Fuga de talento con experiencia específica en la herramienta elegida.

#### D. Alternativas descartadas

Lista **al menos 3** alternativas evaluadas y por qué se descartan **hoy** (pero podrían volver con otros disparadores):

- **Flux v2** (la otra opción principal).
- **Mantener Jenkins + `helm upgrade`** (status quo).
- **Jenkins X / Spinnaker** (opciones de generación anterior).
- **Combinación Argo CD + Flux** en dominios distintos (p. ej. Flux para add-ons del cluster, Argo CD para apps).
- **Crossplane como motor único** (gestionar incluso cloud por GitOps).

Para cada una: una frase de pros, una de contras, una de "cuándo sí".

### 5.4 Preguntas obligatorias (al final de `ADR.md`)

Numera las respuestas **del 1 al 7**:

1. ¿Cuál es el **argumento más débil** para elegir Argo CD o Flux (nombra el "antipatrón de decisión")? Explica por qué.
2. En el escenario, el CISO pide que "todo cambio pase por PR". ¿Esto descarta Argo CD? Argumenta mencionando cómo se configura la UI de Argo CD para separar lectura de escritura.
3. El lead de plataforma dice "Argo CD invita a tocar en caliente". ¿Es un argumento técnico o cultural? ¿Cómo lo mitigarías si eligieras Argo CD?
4. **Image automation** es un driver importante. Compara, en 3 líneas, cómo lo resuelve Argo CD (add-on `argocd-image-updater`) vs Flux (nativo `image-automation-controller` + `image-reflector-controller`). ¿Cambia tu decisión?
5. Da un escenario alternativo (modifica una variable del escenario original) donde tu decisión **se invertiría**.
6. ¿Cuál es el **costo de migrar** entre Argo CD y Flux a los 2 años, si se diera? Nombra al menos 3 cosas no triviales que habría que rehacer.
7. ¿Qué disparador (de los que listaste en C) te obligaría a volver a abrir este ADR **primero**? ¿Cómo lo medirías?

### 5.5 Validar estructura

```bash
bash tests/validate.sh /tmp/argo-01-adr
```

Chequea que `ADR.md` exista y contenga: las cuatro secciones ADR, mención a Argo CD y a Flux, al menos 2 alternativas evaluadas, menciones a conceptos clave (UI, multi-cluster, image automation, PR, cultura/filosofía), al menos 5 ítems numerados en triggers y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/ADR-reference.md`.

## 6. Resultado esperado

- Archivo `ADR.md` en `/tmp/argo-01-adr/` con secciones Contexto / Decisión / Consecuencias / Alternativas y 7 respuestas numeradas.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/ADR-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Las cuatro secciones (Contexto / Decisión / Consecuencias / Alternativas) aparecen explícitas.
- [ ] Al menos **5 disparadores** medibles y concretos en la sección C.
- [ ] Al menos **3 alternativas** evaluadas en la sección D (una de ellas la "otra" entre Argo CD y Flux).
- [ ] Menciona explícitamente **Argo CD** y **Flux** por nombre.
- [ ] Menciona al menos uno de: UI, multi-cluster, image automation, SSO, Projects, Kustomization, HelmRelease.
- [ ] Las 7 preguntas respondidas (como `1.`, `2.`, ... al inicio de línea).

## 8. Validación

```bash
bash tests/validate.sh /tmp/argo-01-adr
```

Estructural. **Semántica** la calibras tú con `solution/ADR-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Si el equipo de plataforma fuera de **1 persona** en vez de 3, ¿cambiaría tu decisión? ¿Por qué?
2. ¿Qué pasaría si la organización ya tuviera **experiencia profunda con Flux** de otra startup del grupo? ¿Es un factor legítimo para la decisión?
3. ¿Cuándo tiene sentido **no elegir ninguno de los dos** y quedarse con un enfoque custom (p. ej. `kubectl apply` desde un controller propio)?

## 10. Extensiones (opcional)

- **E1** — Reescribe el ADR eligiendo **la opción contraria** (si elegiste Argo CD, defiende Flux; o viceversa). Observa qué criterios cambian de peso.
- **E2** — Añade una sección "**migración**" con los pasos de 30/60/90 días para pasar de Jenkins push al nuevo stack GitOps, respetando el principio de "cortar el acceso del CI al cluster como primer corte".
- **E3** — Investiga el proyecto **Argo Autopilot** (si sigue vivo) y explica si cambia tu análisis.

## 11. Limpieza

```bash
rm -rf /tmp/argo-01-adr
```
