# Ejercicio arquitectónico — Decisión de migración de Jenkins

> **Dimensión:** arquitectónica. **Peso dentro del examen:** 30%. **Tiempo sugerido:** 30–40 min.
> Entregar `architectural/submission/ADR.md` (plantilla MADR). Prosa en español, snippets/nombres de recursos en inglés.

---

## Contexto

Eres la nueva persona de **Platform Engineering** en **NorthBank**, un banco mediano con ~400 ingenieros. La situación del CI actual:

- **1 controller Jenkins LTS** on-prem (VM Linux), 7 años de antigüedad, operado por un equipo que ya no existe.
- `JENKINS_HOME` de **42 GB**: ~1200 jobs, de los cuales:
  - ~380 son **Freestyle** configurados por UI (nadie recuerda qué hacen la mitad).
  - ~520 son **Pipeline** con `Jenkinsfile` en Git.
  - ~300 están **deshabilitados** desde hace >6 meses (nadie los borra "por si acaso").
- **94 plugins** instalados; 11 con CVE abierto; **sin JCasC**.
- 1 **Shared Library** (`bank-common`) cargada con `@Library('bank-common') _` (sin pin), con ~60 steps globales y **sin tests**.
- Agents: 8 VMs permanentes compartidas entre todos los equipos (contamination recurrente). **Sin Kubernetes plugin.**
- Secretos: mezcla de `credentials()` en pipeline, variables de entorno globales del controller y, en algunos jobs legacy, **secretos hardcodeados** en el campo "Execute shell" de Freestyle.
- Autorización: `Logged-in users can do anything`.

**Repositorios de código:**

- 60% en **GitHub Enterprise Server** (on-prem).
- 25% en **GitLab self-hosted**.
- 15% en Bitbucket Server (planeado deprecar en 2027).

**Plataforma destino en construcción:**

- Un cluster **EKS** nuevo para workloads de plataforma; política interna favorece **K8s-native** cuando aplica.
- Cuentas AWS con **OIDC** ya habilitado contra GitHub Actions.
- Equipo de seguridad exige: rotación obligatoria de credenciales en los próximos 6 meses y **eliminación de secretos long-lived** cuando sea posible.

**Restricciones:**

- Presupuesto: 2 ingenieros × 6 meses para la migración (dedicados ~50%).
- No se puede detener el flujo de releases durante la migración (es un banco, hay auditoría regulatoria).
- CFO reticente: "si funciona no lo toques". Head of Engineering impaciente: "quiero Jenkins apagado en 3 meses".

---

## Tu tarea

Entregar un **ADR en formato MADR** (`ADR.md`) que cubra, como mínimo, estas secciones:

1. **Contexto** (reformulado por ti, no copiado).
2. **Decisión** (elección de target o combinación de targets).
3. **Alternativas consideradas** con trade-offs.
4. **Consecuencias** (positivas y negativas).
5. **Plan de ejecución** por fases con criterios de salida de cada fase.
6. **Plan de rollback** y criterios de abort.
7. **Métricas de éxito** observables post-corte.

El ADR debe responder explícitamente a estas preguntas (puedes integrarlas en las secciones de arriba, no hace falta una sección por pregunta):

- **A.** ¿Cómo inventarías y clasificas los 1200 jobs (incluidos los 380 Freestyle fantasma y los 300 deshabilitados)? Define criterios objetivos de `migrar` / `consolidar` / `retirar`.
- **B.** ¿Qué target eliges para qué tipo de workload? Justifica contra alternativas:
  - Repos en GitHub → ¿GHA? ¿Argo Workflows? ¿ambos según workload?
  - Repos en GitLab → ¿GitLab CI? ¿otro?
  - Workloads K8s-native nuevos → ¿Tekton / Argo Workflows?
  - Monolitos legacy difíciles de portar → ¿se quedan en Jenkins "por ahora"? ¿con qué criterio salen?
- **C.** ¿Cómo diseñas el **dual-run**? Define ventana, criterios de paridad (qué significa "el pipeline nuevo es equivalente al viejo"), criterios de retiro del pipeline Jenkins original y criterios de **abort** (volver a ejecutar sólo en Jenkins).
- **D.** ¿Cómo tratas la Shared Library `bank-common` sin tests? ¿Portarla tal cual, reescribirla en el ecosistema target, o escribirla como librería compartida reusable (reusable workflow / CI/CD Component / Argo WorkflowTemplate) desde cero? Da criterios.
- **E.** ¿Qué haces con los **secretos hardcodeados** detectados en Freestyle jobs durante el inventario? ¿Cómo evitas que la migración los copie al nuevo sistema?
- **F.** ¿Cómo migras de `withCredentials` a **OIDC federation** al cloud (donde aplique)? ¿Qué hacés con los pipelines on-prem que no tienen conectividad a STS?
- **G.** ¿Cómo defendés el plan contra el CFO ("si funciona no lo toques") y contra el Head of Engineering ("Jenkins off en 3 meses")? Da **dos argumentos observables** para cada bando.
- **H.** ¿Qué hacés con el Jenkins existente **mientras dure la migración**? ¿Lo endurecés? ¿Lo congelás? ¿Qué cambios de JCasC/RBAC/plugins aplicás **ya** aunque vaya a morir en 6 meses?

---

## Entregable

```
architectural/submission/
  ADR.md
```

El ADR puede incluir diagramas (mermaid o enlazados). No debe superar **~1500 palabras** (sin contar diagramas y tablas); se evalúa calidad del razonamiento, no volumen.

---

## Rúbrica (detalle)

| Criterio                        | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---------------------------------|------------------|------------|----------------|-------------|
| Inventario y clasificación (A)  | No lo aborda o es cualitativo sin criterios | Lista jobs pero sin criterios de clasificación | Clasifica migrar/consolidar/retirar con criterios explícitos | + prioriza por riesgo × valor y define quién decide |
| Elección de target (B)          | Elige un único target por dogma, sin análisis | Elige con trade-offs genéricos | Elige con trade-offs claros vs alternativas | + diferentes targets por tipo de workload con rationale observable |
| Plan de dual-run (C)            | Ausente o "lo corremos en paralelo un rato" | Mencionado sin criterios | Define ventana, criterios de paridad, retiro y abort | + instrumentación concreta (hashes de artefactos, diff de resultados) |
| Shared Library legacy (D)       | No la aborda | Porta tal cual | Decide por step según uso y riesgo | + plan de deprecación con fechas y owners |
| Secretos hardcodeados (E)       | No los detecta/menciona | Los menciona genérico | Define proceso de scan + rotación forzada + no-copia al target | + bloqueo del pipeline nuevo si el scan detecta carryover |
| OIDC migration (F)              | No la menciona | La menciona genérico | `withCredentials` → OIDC donde haya conectividad; alternativa (Vault/short-lived) para on-prem sin STS | + política de "no credenciales long-lived" con excepciones documentadas |
| Argumentos contra extremos (G)  | No defiende el plan | Defensa retórica sin métricas | Argumentos observables para ambos bandos | + propone experimento acotado que convenza a ambos en 2 semanas |
| Hardening de Jenkins actual (H) | "Lo apagamos pronto, no vale la pena" | Cambios cosméticos | RBAC + Role Strategy + pin de plugins + eliminación de secretos literales ya | + plan de "freeze de cambios" en el controller moribundo |
| Calidad del ADR (MADR)          | Faltan secciones | Decisión sin consecuencias ni rollback | Secciones completas | + métricas de éxito observables y criterios cuantitativos de corte |

**Umbral de aprobación del arquitectónico:** promedio ≥ 1.5 **y** ningún criterio en 0. Un criterio en 0 puede ser compensado por otros ≥ 2.5 **salvo** si está marcado como red flag.

### Red flags del ejercicio arquitectónico

- Propone **big-bang migration** sin dual-run.
- Propone **dual-run indefinido** sin criterios de retiro.
- No menciona los secretos hardcodeados o propone copiarlos como estén al nuevo sistema.
- Deja el controller actual con `Logged-in users can do anything` "porque va a morir".
- Elige un único target por dogma ("todo a Argo porque es más cool", "todo a GHA porque es SaaS") sin considerar el repo de origen ni el tipo de workload.
- No ofrece plan de rollback.
- Promete el apagado en 3 meses sin justificación de capacidad.

---

## Guía de corrección (instructor-only)

### Respuesta de referencia (resumen)

Target recomendado: **mix por repo + tipo de workload**:

- Repos en GitHub → **GHA** como default; **Argo Workflows** para pipelines data/batch K8s-native con fan-out alto.
- Repos en GitLab → **GitLab CI** (minimiza cambio cognitivo del equipo; menos integraciones a reescribir).
- Workloads de plataforma nuevos sobre EKS → **Argo Workflows** o **Tekton** (K8s-native, GitOps-friendly).
- Monolitos legacy con dependencias raras → **se quedan en Jenkins** temporalmente, pero sólo si pasan hardening mínimo (RBAC + credenciales rotadas + plugin audit) y entran en una lista explícita con **fecha de corte**.

Inventario (A): script que recorre `JENKINS_HOME/jobs/*/config.xml` para extraer tipo, última ejecución, owner (via `CODEOWNERS` del repo asociado si existe), secretos referenciados y plugins usados. Clasificación:

- `retirar`: deshabilitado > 6 meses **o** sin owner identificable **o** sin ejecuciones en 12 meses.
- `consolidar`: múltiples jobs que hacen lo mismo con parámetros distintos → convertir a un pipeline parametrizado único en el target.
- `migrar`: el resto, priorizado por frecuencia de ejecución × criticidad.

Dual-run (C): ventana **4–8 semanas por pipeline crítico**. Paridad = artefactos binarios idénticos (hash) o, cuando no sea posible, resultados funcionales equivalentes (misma suite de tests pasa, mismo deploy produce el mismo estado). Retiro = N ejecuciones consecutivas (p. ej. 20) sin diferencia + firma del owner del servicio. Abort = cualquier diferencia no explicada en artefactos de release.

Secretos hardcodeados (E): scan automático durante el inventario (TruffleHog / gitleaks sobre `config.xml`), rotación forzada **antes** de migrar el job, y bloqueo del pipeline nuevo si el scan de secrets detecta carryover.

OIDC (F): migrar `withCredentials` a OIDC federation donde haya conectividad a STS; para pipelines on-prem sin STS, usar **Vault** con tokens short-lived (TTL ≤ 1 h) como paso intermedio hasta que la red se abra. Política: "cero credenciales long-lived nuevas; las existentes caducan en N meses".

Hardening del Jenkins actual (H): aplicar **ya** JCasC mínimo + Role Strategy + pin de plugins + eliminación de secretos literales **aunque** el controller vaya a morir en 6 meses — la migración puede extenderse y mientras tanto la superficie de ataque sigue viva.

### Señales de respuesta débil

- "Portamos los 1200 jobs tal cual a GHA en 3 sprints."
- "El dual-run lo dejamos corriendo hasta que estemos cómodos" (sin criterio).
- No distingue entre Shared Library y plugin.
- Omite los secretos hardcodeados o los mueve al nuevo sistema "como están para no bloquear".
- Deja `Logged-in users can do anything` en el controller moribundo porque "ya se apaga".
- Elige target por dogma, sin considerar el repo de origen.
- Promete el apagado en 3 meses sin análisis de capacidad del equipo (2 FTE × 50% × 6 meses ≠ 3 meses).

### Preguntas de seguimiento (live)

- "Encontrás 40 jobs con secretos hardcodeados en el día 2 del inventario. ¿Qué comunicás, a quién, en qué orden, hoy?"
- "El owner de un servicio crítico se niega a migrar porque 'ya tiene bastante trabajo'. ¿Cuál es tu siguiente paso?"
- "Diferencia observable del dual-run: el pipeline nuevo produce una imagen 200 KB más chica. ¿Es paridad o abort?"
