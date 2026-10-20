# sec-01 — Lección: principios, threat modeling y supply chain

> 12 secciones. 100 % conceptual. Prerrequisito: cursos **docker** y **github-actions**.

---

## 1. Punto de partida: por qué "security team al final" fracasa

El modelo tradicional ponía a seguridad **al final**: el equipo de product escribía el código, lo mergeaba y lo subía a staging; el equipo de security revisaba *después*, encontraba problemas y pedía rework. El patrón repetido:

1. El bug ya está en main.
2. Arreglarlo requiere coordinar varios equipos.
3. El coste de corregir en esta fase es **órdenes de magnitud** mayor que haberlo evitado en el commit.
4. Los deadlines ganan y el fix se posterga como "deuda de seguridad".
5. La deuda se acumula hasta que un incidente la convierte en noticia.

El coste de un fallo es una curva exponencial sobre **dónde se detecta**: diseño → código → PR → CI → staging → producción → incidente público. El patrón DevSecOps no es "añadir seguridad", es **mover la detección a la izquierda** de la curva para que sea barata.

> **Idea clave que repetiremos:** una amenaza existe cuando hay **(atacante + motivo + vector)**. Eliminar un **vector** es más barato que detectar un **abuso**. Eliminar el abuso es más barato que gestionar un incidente. Y gestionar un incidente es más barato que explicarle a tus usuarios por qué sus datos están a la venta.

---

## 2. Shift-left y defense-in-depth: complementarios, no rivales

El eslogan "shift-left" se malinterpreta como "muevo todo a la izquierda y ya no necesito controles en runtime". Falso.

- **Shift-left** = detectar y prevenir **antes** (linters, SAST, pre-commit hooks, PR checks, IaC scanning sobre el plan).
- **Shift-right / defense-in-depth** = detectar y responder **durante y después** (runtime security, admission controllers, SIEM, auditoría, bug bounty).

Son **capas**. Cada capa deja pasar un porcentaje de amenazas; la siguiente capa cubre lo que escapó. Pretender que solo una capa es suficiente es el modo clásico de fracasar:

- Solo shift-left: no detectas zero-days en dependencias que ya corren en prod, ni insiders.
- Solo shift-right: ya se filtró el secreto cuando lo notas; recoges metralla.

**Analogía útil:** aeropuertos tienen scan de equipaje (shift-left), control de pasaportes (medio), cámaras y guardas en la pista (shift-right). Nadie confía en un único control.

---

## 3. Threat modeling: qué es y qué no es

Threat modeling es el ejercicio sistemático de responder:

1. **¿Qué estamos construyendo?** (DFD mínimo, componentes, dataflows, trust boundaries).
2. **¿Qué puede ir mal?** (STRIDE, abuser stories, kill chains).
3. **¿Qué hacemos al respecto?** (mitigaciones priorizadas por coste/beneficio).
4. **¿Hicimos un buen trabajo?** (revisión con los equipos involucrados).

Las trampas típicas:

- **Ceremonia pesada**: generar documentos de 80 páginas que nadie lee. Un threat model que no se revisa en el PR es decorativo.
- **Threat model universal**: pretender cubrir "todo el sistema" en una sesión. Mejor: un threat model por feature o por cambio arquitectónico significativo.
- **"Lo haremos cuando tengamos tiempo"**: nunca es el momento. Threat model al nivel de madurez correcto desde el día 1 (una página basta al principio).

> **Idea clave:** el output útil de un threat model no es el documento, es el **conjunto de mitigaciones** que acabas aplicando y las **assumptions** que quedan registradas.

---

## 4. STRIDE: las 6 letras

STRIDE es un mnemotécnico de Microsoft (1999) que enumera **categorías de amenazas**:

| Letra | Amenaza | Pregunta guía | Ejemplo típico en una API web |
|-------|---------|---------------|-------------------------------|
| **S** | **Spoofing** | ¿Alguien puede hacerse pasar por otro? | JWT sin firma válida; sesión robada; DNS hijack. |
| **T** | **Tampering** | ¿Alguien puede modificar datos en tránsito o reposo? | Mutación de payload sin integridad; UPDATE directo a DB; mutación de imagen en registry sin firma. |
| **R** | **Repudiation** | ¿Alguien puede negar haber hecho algo? | Falta de audit log; logs editables por el actor; sin firma de commits en entregas regulatorias. |
| **I** | **Information disclosure** | ¿Se filtran datos a quien no debería verlos? | Stack trace en respuesta HTTP; S3 bucket público; secreto en env var; log con PII. |
| **D** | **Denial of service** | ¿Alguien puede dejar el servicio caído o degradado? | Rate limit ausente; query sin paginación; regex con backtracking exponencial. |
| **E** | **Elevation of privilege** | ¿Alguien puede ganar permisos que no tiene? | SQL injection → RCE; container con `--privileged`; sudo sin NOPASSWD mal configurado. |

**Cómo usarlo**: recorres el DFD y para **cada dataflow** y **cada componente** te preguntas las 6 letras. No todas aplican a todo — está bien marcar "N/A, por X motivo". Lo importante es **haber mirado**.

---

## 5. Data Flow Diagrams (DFD): lo mínimo para que las amenazas emerjan

Un DFD es un diagrama con 4 símbolos:

- **Entidad externa** (rectángulo): usuario, otro servicio, una API externa.
- **Proceso** (círculo): algo que transforma datos (tu API, tu worker).
- **Almacén** (dos líneas paralelas): DB, cache, bucket.
- **Flujo** (flecha): dato que se mueve de A a B.

Y un elemento clave: **trust boundary** (línea discontinua) que marca dónde cambia el nivel de confianza. Cada vez que un flujo cruza un trust boundary, STRIDE se vuelve más interesante.

Ejemplo mínimo para una API con DB:

```
   [Usuario] ═══╗
                ║      trust boundary (internet → LAN privada)
   ─ ─ ─ ─ ─ ─ ─╬─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
                ▼
             ( API )  ──────► [[ DB ]]
                │
                └──────────► [[ Cache ]]
```

Lo bueno de un DFD mínimo: cabe en una pizarra, se discute en 15 min, y hace **emerger** las preguntas correctas (¿cómo autentica el usuario a la API? ¿cómo autentica la API a la DB? ¿quién puede leer el cache?).

> **Idea clave:** un DFD **no es un diagrama arquitectónico**. No busca ser exhaustivo. Busca que los **flujos de datos** y los **límites de confianza** sean visibles.

---

## 6. Trust boundaries en profundidad

Un trust boundary separa dos zonas con niveles de confianza distintos. Son el lugar donde **todas las decisiones de seguridad importantes ocurren**:

- Internet ↔ LAN privada.
- LAN privada ↔ VPC/subnet aislada.
- Namespace K8s ↔ otro namespace.
- Container ↔ host.
- Código de aplicación ↔ librería 3P (sí, cada `import` cruza un trust boundary — eso es la supply chain).
- CI runner ↔ secrets manager.
- Developer laptop ↔ repo remoto.

Reglas prácticas:

1. **Autenticación** en cada cruce (saber *quién* es la otra parte).
2. **Autorización** en cada cruce (saber *qué puede hacer*).
3. **Validación** de todo input al cruzar (nunca confíes en lo que te manda otra zona, aunque sea "interna").
4. **Encriptación** si el canal pasa por una zona de menor confianza.
5. **Audit log** de cruces sensibles.

Si una zona que creías aislada deja de estarlo (p. ej. una VPN entre dos cuentas AWS), **re-visita el threat model**: los flujos que antes vivían en un trust boundary ahora cruzan otro.

---

## 7. Supply chain: la nueva superficie de ataque

Durante años el modelo mental fue "mi código es mío, mis dependencias son de otros pero *confiables*". Esa confianza se evaporó entre 2020 y 2024 con cuatro incidentes de referencia:

### 7.1 SolarWinds (2020)

Atacantes comprometieron el **build system** de SolarWinds e inyectaron código malicioso en el binario Orion firmado y distribuido a ~18 000 organizaciones (incluyendo agencias federales US). Lección: la firma del vendor **no basta** si el build system está comprometido. Nace SLSA como respuesta directa.

### 7.2 log4shell (CVE-2021-44228)

Una funcionalidad "legitima" de log4j (JNDI lookup en strings loggeados) permitía RCE desde cualquier string que la aplicación loggeara. Lección: una **dependencia transitiva** (log4j venía como transitive de cualquier app Java) puede comprometer toda la industria. SBOMs y SCA pasaron de "buena idea" a mandatorios.

### 7.3 xz-utils backdoor (CVE-2024-3094, 2024)

Un maintainer malicioso ("Jia Tan") pasó **2 años** ganando confianza en el proyecto xz-utils, acabó siendo co-maintainer, e introdujo un backdoor en el build system (no en el código fuente visible) que comprometía `sshd`. Detectado por casualidad por un ingeniero de Microsoft que notó medio segundo de latencia extra. Lección: la **persistencia** de atacantes bien financiados contra proyectos OSS con pocos maintainers es real; social engineering a largo plazo es un vector.

### 7.4 tj-actions/changed-files (2025)

Compromiso de un **GitHub Action** popular (`tj-actions/changed-files`): el atacante consiguió push al repo del action y publicó una versión que exfiltraba secretos del runner a un servidor externo. Como miles de repos pineaban por **tag mutable** (`@v35`) en vez de por **SHA inmutable**, el compromiso se propagó en horas. Lección: **pinnear por SHA**, no por tag; auditar permisos del `GITHUB_TOKEN`; usar `permissions:` restrictivos.

> **Patrón común:** la cadena de suministro tiene **más superficie** que tu código. Cada dependencia, cada action, cada base image, cada builder es un trust boundary.

---

## 8. SLSA: niveles 1 a 4 (visión)

**SLSA** (Supply-chain Levels for Software Artifacts, pronunciado "salsa") es un framework de la OpenSSF que define **niveles progresivos de garantía** sobre cómo se construye un artefacto. v1.0 (2023) simplificó el modelo original a 3 niveles operativos + L4 reservado.

### L0 — Sin garantía

No existe build definido ni documentado. Alguien podría estar compilando en su laptop.

### L1 — Build script documentado

- Existe un **build script** reproducible (Dockerfile, Makefile, workflow).
- Se publica una **provenance** mínima que dice "este artefacto salió de este script".
- Hashes/digests publicados.

Protege contra: errores humanos triviales ("¿qué commit es este tag?"). No protege contra atacantes.

### L2 — Hosted build + provenance firmada

- El build corre en un **builder hospedado** (GitHub Actions, GCB, Buildkite Cloud) — no en una laptop.
- La **provenance** se genera **por el builder**, no por el autor del código.
- La provenance está **firmada** por el builder.

Protege contra: provenance forjada por el autor; manipulación trivial del artefacto post-build.

### L3 — Non-forgeable provenance + builder isolation

- El builder garantiza que el **autor no puede escribir** en el proceso de generación de provenance (keyless signing con OIDC claim del builder).
- Builds son **isolated**: no se contaminan entre runs.
- Materiales (código fuente, dependencias) listados con digests verificables.

Protege contra: builder environment manipulation; cross-build contamination; compromiso del repo que intente reescribir provenance.

### L4 — Reservado / aspiracional

v1.0 lo deja sin especificar; versiones previas lo asociaban a **two-party review** (todo cambio con dos personas) y **hermetic/reproducible builds** completos. Sigue en discusión.

**En práctica:** GitHub Actions con `actions/attest-build-provenance` + Fulcio/Rekor te lleva a **L3** sin esfuerzo heroico. Esto se profundiza en `sec-08` y `sec-09`.

---

## 9. SBOM y provenance: dos preguntas distintas

**Confusión recurrente:** la gente mezcla SBOM con provenance porque "ambos describen el artefacto". No son lo mismo.

| Dimensión | SBOM | Provenance |
|-----------|------|------------|
| Pregunta | ¿**Qué** hay dentro? | ¿**Cómo** se construyó? |
| Analogía | Lista de ingredientes | Factura del fabricante |
| Formato típico | **CycloneDX**, **SPDX** | **in-toto attestation** (SLSA predicate) |
| Herramienta típica | `syft`, `cdxgen` | `actions/attest-build-provenance`, `slsa-github-generator` |
| Responde a | "¿tengo log4j vulnerable?" | "¿este artefacto salió de main del repo oficial?" |
| Cambio esperado | Cambia con cada dependencia | Cambia con cada build |

Un consumidor sano quiere **ambos**:

- SBOM para **triage de vulnerabilidades** (dado un CVE, ¿me afecta?).
- Provenance para **verificar origen** (¿es realmente el binario que esperaba, construido como esperaba?).

Las dos capas se **firman por separado** (ver `sec-09` para firma con cosign). SBOM responde a *qué*; provenance responde a *de dónde*. Preguntas ortogonales, artefactos ortogonales.

---

## 10. Threat model mínimo útil: estructura de una página

Un threat model útil cabe en una página. Estructura recomendada:

```markdown
# Threat model — <nombre del servicio>  — v<fecha>

## 1. Scope
- Qué cubre esta iteración (p. ej. endpoint /checkout, no todo el servicio).
- Qué queda fuera y por qué.

## 2. DFD (ASCII o imagen)
- Entidades, procesos, almacenes, flujos.
- Trust boundaries marcados.

## 3. Assets
- Lista de datos/componentes valiosos y por qué (PII, secrets, dinero).

## 4. Threats (tabla STRIDE)
| ID | Letra | Amenaza concreta | Afecta a | Likelihood | Impact | Mitigación |
|----|-------|------------------|----------|------------|--------|------------|

## 5. Assumptions
- Lista explícita de cosas que asumimos (ej.: "la DB está en subnet privada").
- Cada assumption es una invitación a un futuro threat model si cambia.

## 6. Open questions
- Lo que no sabes resolver aquí y lleva ticket.
```

Reglas:

- No más de **10–15 amenazas** por iteración. Si tienes 50, el scope era demasiado grande.
- **Priorizar** por `likelihood × impact`, no por "la que más miedo me da".
- **Mitigación ≠ control teórico**. Debe ser un ticket, un PR, o una decisión documentada.
- **Fecha** visible: un threat model sin fecha es un threat model muerto.

---

## 11. Mitigaciones: coste vs beneficio

Toda amenaza admite varias respuestas:

- **Evitar** (eliminar el vector): mejor opción cuando es barato. Ej.: quitar un endpoint que nadie usa.
- **Mitigar** (reducir el daño): la mayoría de los casos. Ej.: rate limit, validation, encrypt at rest.
- **Transferir** (que otro corra con el riesgo): seguros, SaaS que firman SLA.
- **Aceptar** (riesgo bajo + mitigación cara): registrado explícitamente, con responsable y fecha de revisión.

El error más común: **"aceptar" por olvido**. Si una amenaza no está mitigada y nadie firmó la aceptación, es deuda invisible. Un buen threat model fuerza decisiones explícitas.

**Heurística de priorización (barata):**

| Likelihood | Impact | Acción típica |
|-----------|--------|---------------|
| Alta | Alto | **Mitigar YA** (bloqueante de release). |
| Alta | Bajo | Mitigar en el próximo sprint. |
| Baja | Alto | Mitigar o aceptar con control compensatorio. |
| Baja | Bajo | Aceptar / documentar. |

---

## 12. Qué hemos aprendido y qué viene después

Hemos repasado:

- Por qué DevSecOps nace de la insuficiencia del modelo "security team al final".
- Shift-left y defense-in-depth como capas complementarias.
- Threat modeling práctico con **STRIDE** sobre un **DFD mínimo**, apoyado en **trust boundaries**.
- La supply chain como superficie emergente, con cuatro incidentes de referencia (**SolarWinds**, **log4shell**, **xz-utils**, **tj-actions**).
- **SLSA v1.0** como escalera de madurez (L1 → L2 → L3).
- **SBOM** vs **provenance** como respuestas a preguntas ortogonales.
- Threat model de una página con tabla STRIDE priorizada.

Lo que viene:

- **`sec-02`**: dónde pueden vivir los secretos y qué principios aplican antes de elegir una herramienta.
- **`sec-03`**: taxonomía de scanners (SAST, DAST, SCA, IaC, container, secret) y política de severidad.
- **`sec-08`**: emitir SBOMs y provenance en pipelines reales.
- **`sec-09`**: firmar artefactos con cosign (modelo keyless, Fulcio, Rekor).

> **Mantra del módulo:** la cadena de suministro es tan segura como su eslabón más débil, y hoy casi siempre ese eslabón es **la provenance ausente o no verificada**.
