# solution/REFERENCE.md — plat-09-02

Referencia para autoevaluar. **No** la mires antes de haber escrito tu ADR.

## Decisiones razonables (no únicas) por contexto

### Contexto 1 — Scale-up SaaS K8s-first

**Decisión:** **Crossplane**.

- Stack ya K8s-first, Argo CD y Kyverno maduros → heredar RBAC, GitOps, policies es victoria neta.
- 8 productos de plataforma amortizan la curva de aprendizaje del equipo platform (6 personas).
- 300 developers con RBAC K8s existente → claims en sus namespaces encajan sin diseño nuevo.
- TF para infra base (VPC, EKS, IAM) se queda; **híbrido justificado**: TF para la plataforma; Crossplane para los productos encima.

**Riesgo:** upgrade de providers y breaking changes de Crossplane. **Mitigación:** owner rotativo, cadencia trimestral, canary de productos antes de rollout global.

### Contexto 2 — Empresa industrial legacy

**Decisión:** **Terraform-via-PR** (Atlantis).

- Lingua franca TF, repo monorepo-ish de 500k líneas → el costo de "otro paradigma" es prohibitivo con sólo 2 productos a publicar.
- Atlantis ya estable → **extender** el ya probado tiene mejor ROI.
- El platform team (4 personas) no tiene bandwidth para operar un control plane extra.
- Mainframe-adjacent y VMs quedan fuera del scope K8s de todos modos.

**Riesgo:** si en 2 años el catálogo crece a 10+ productos, el modelo TF-PR se vuelve tedioso. **Mitigación:** revisar la decisión anual.

### Contexto 3 — Startup Series B multi-cloud

**Decisión:** **Crossplane**, pero con reserva.

- Multi-cloud real (EKS + GKE) → composición nativa de Crossplane evita duplicar módulos TF.
- Experiencia K8s profunda del equipo → curva de aprendizaje real pero asumible.
- 4 productos en 3 meses es poco; con sólo 2 ingenieros platform, el **costo operacional** del control plane es la amenaza.
- Alternativa defendible: TF-via-PR en el primer trimestre, Crossplane en el segundo si el catálogo confirma crecimiento.

**Riesgo:** sobre-ingeniería con 15 servicios. **Mitigación:** empezar con 1 producto (namespace) y validar en 60 días antes de añadir más.

## Comparativa en 7 dimensiones (referencia)

| Dimensión | Crossplane | Terraform-via-PR |
|-----------|------------|-------------------|
| Stack dominante | K8s-first | TF-first |
| Curva de aprendizaje | Alta (XRD, Composition, patches, functions) | Baja (TF estándar + Atlantis config) |
| Debugging de fallo | Opaco (status de claim → XR → MR → provider logs) | Transparente (`terraform plan`/`apply`) |
| GitOps | Nativo (Argo CD aplica CRs) | Externo (Atlantis / GHA / TFC) |
| Policy-as-code | Kyverno / OPA Gatekeeper sobre claims | Sentinel / OPA / policy-as-code en TF |
| Overhead operacional | Control plane permanente + upgrades de providers | Runners CI o SaaS; no control plane extra |
| Rollback | Delete XR (ojo con `deletionPolicy`) | `terraform destroy` o revert PR |

## 5 preguntas-criterio (referencia)

1. ¿Cuántos **productos de plataforma distintos** prevemos publicar en 12 meses? (<3 → favor TF-PR; ≥5 → favor Crossplane)
2. ¿Nuestro stack ya es K8s-first con **GitOps productivo** (Argo CD / Flux)?
3. ¿El platform team tiene **experiencia K8s profunda** o es TF-first?
4. ¿Tenemos **deuda TF** significativa (monorepo grande, Atlantis estable) que extender?
5. ¿Necesitamos **multi-cloud real** con composiciones (no sólo "soportamos AWS y GCP")?
