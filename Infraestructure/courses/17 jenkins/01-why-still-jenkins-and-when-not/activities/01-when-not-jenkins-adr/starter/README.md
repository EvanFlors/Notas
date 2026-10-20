# Starter — jk-01-01-when-not-jenkins-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre los dos `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-01-adr
   cd /tmp/jk-01-adr
   ```
3. Crea `ADR-JENKINS-DECISION.md` con las 6 secciones requeridas:
   - Estado, Contexto, Decisión, Consecuencias, Alternativas (más el encabezado ADR).
4. Incluye en la Decisión:
   - Un diagrama ASCII en code fence (árbol de decisión o arquitectura target).
   - Al menos 3 alternativas comparadas (GHA, GitLab CI, Argo Workflows, Tekton o CloudBees).
   - Mención del framework de migración con al menos 3 pasos (inventario, clasificación, dual-run, OIDC, retirada).
   - Mención explícita de constraints del escenario: on-prem, GDPR/Solvency II, compliance, auditoría.
   - Freestyle vs pipeline / `Jenkinsfile`.
   - Riesgo de superficie CVE / plugins / script approval.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/jenkins/01-why-still-jenkins-and-when-not/activities/01-when-not-jenkins-adr/tests/validate.sh /tmp/jk-01-adr
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura y presencia de términos, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

```markdown
# ADR 001 — Decisión sobre Jenkins en Nordhaus Insurance

## Estado
Propuesto

## Contexto
<por qué, qué constraints: 1.400 jobs legacy, on-prem obligatorio,
GDPR + Solvency II, 180 plugins, CVEs recientes, 2 personas dedicadas>

## Decisión

### 1. Recomendación

<Mantener modernizando + preparar migración por olas a GitLab CI
self-managed. Horizonte 18-24 meses.>

### 2. Comparación de alternativas

| Opción | Pros | Contras |
|--------|------|---------|
| Mantener Jenkins "as is" | ... | ... |
| GHA (GitHub Enterprise Server) | ... | ... |
| GitLab CI self-managed | ... | ... |
| Argo Workflows (puro K8s) | ... | ... |

### 3. Framework de migración (aplicado)
1. Inventario de los 1.400 jobs...
2. Clasificación migrar / consolidar / retirar...
3. Dual-run de la primera ola...
4. OIDC federation al cloud / al cluster...
5. Retirada ordenada de Jenkins cuando ...

### 4. Freestyle vs Pipeline
...

### 5. Superficie CVE / plugins / sandbox
...

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: migrar todo a GitLab CI en 6 meses (big-bang)
- Por qué no: ...
### Alt B: congelar Jenkins y hacer todo lo nuevo en GHA
- Por qué no: ...
```
