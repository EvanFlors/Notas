# Actividad 02 — Protected environment `production` con approval rules

## 1. Identificacion

- **ID:** `gl-07-02-approval-rule-prod`
- **Tecnologia:** `gitlab-cicd`
- **Modulo:** `gl-07-environments-deployments-and-review-apps`
- **Dificultad:** advanced
- **Duracion estimada:** 60–90 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu organizacion es un marketplace B2B con 40 ingenieros. El entorno `production` corre en EKS y recibe ~5 despliegues/dia. Un incidente hace 6 meses (deploy a prod sin revisar un cambio de migracion) causo 2h de downtime y multas por SLA. El post-mortem exigio dos controles:

1. **Deploy a `production` restringido** — solo miembros del grupo `@platform-admins` pueden arrancar un deployment a `production`.
2. **Approval multi-equipo** — todo deployment a `production` requiere al menos **1 aprobacion de `@sre`** y **1 aprobacion de `@security`** antes de arrancar.

Tu encargo: **modelar esta politica como configuracion YAML declarativa** (como la aplicarias con Terraform `gitlab_project_protected_environment` o con un script contra la API `POST /projects/:id/protected_environments`) y escribir un ADR que la justifique.

**Importante**: no se aplica a un proyecto GitLab real. El entregable son **archivos YAML + un ADR**.

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Escribir la configuracion de un protected environment con `deploy_access_levels` y `approval_rules`.
- Distinguir con precision entre `rules:` del pipeline y approval rules del protected environment.
- Diseñar una politica multi-aprobador justificada.
- Documentarla en un ADR legible por un auditor externo.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` §6 (protected environments y approval rules).
- Haber recorrido `../../examples/03-protected-env-approval/`.
- Haber completado `gl-04` (rules/workflow).
- Herramientas locales: `bash`, `python3` con `pyyaml`, editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-07-02-approval-prod
cd /tmp/gl-07-02-approval-prod
```

### 5.2 Escribe `protected-environment.yaml`

Esquema minimo:

```yaml
name: production
deployment_tier: production
deploy_access_levels:
  - group: platform-admins
# (Opcional, pero recomendado): quien puede ejecutar un on_stop
# approval_rules va en archivo separado para mantenerlos cohesivos.
```

Reglas que el validador exige:

- `name` debe ser exactamente `production`.
- `deployment_tier` debe ser `production`.
- `deploy_access_levels` debe listar al menos un grupo (`platform-admins`, `sre`, o el que elijas) — no vale restringir con `access_level: maintainer` solamente, aunque GitLab lo acepte, porque el ADR debe defender restriccion por grupo.

### 5.3 Escribe `approval-rules.yaml`

Esquema minimo:

```yaml
environment: production
approval_rules:
  - group: sre
    required_approvals: 1
  - group: security
    required_approvals: 1
```

Reglas que el validador exige:

- Debe existir una regla para el grupo `sre` con `required_approvals >= 1`.
- Debe existir una regla para el grupo `security` con `required_approvals >= 1`.
- Pueden añadirse mas reglas si lo justificas en el ADR.

### 5.4 Escribe `ADR-APPROVAL-PROD.md`

Formato ADR estandar con las mismas 6 secciones que en actividad 01:

1. `# ADR` (titulo).
2. `## Estado` / `Status`.
3. `## Contexto` / `Context`.
4. `## Decision` / `Decisión`.
5. `## Consecuencias` / `Consequences`.
6. `## Alternativas` / `Alternatives` (>= 2).

Contenido minimo obligatorio (el validador lo verifica):

- Mencion explicita de **protected environment** y de **approval rule(s)**.
- Mencion de **`deploy_access_levels`**.
- Mencion de los grupos **`sre`** y **`security`**.
- Explicacion de la diferencia entre `rules:` (pipeline) y approval rule (environment).
- Mencion de **GitHub Actions** o **GHA** como punto de comparacion.
- Al menos un bloque de codigo (fences) con un snippet YAML.

### 5.5 Entregables

```
/tmp/gl-07-02-approval-prod/
├── protected-environment.yaml
├── approval-rules.yaml
└── ADR-APPROVAL-PROD.md
```

## 6. Resultado esperado

- Los dos YAML parsean correctamente y tienen las claves obligatorias.
- El ADR cubre las 6 secciones y las menciones requeridas.
- El validador pasa en verde.

## 7. Criterios de aceptacion

- **Funcionalidad**: los YAML podrian aplicarse via Terraform/API con cambios cosmeticos.
- **Calidad**: el ADR distingue correctamente los dos planos (pipeline rules vs approval rules) y defiende la eleccion multi-grupo.
- **Reproducibilidad**: un auditor podria leer el ADR y verificar la implementacion contra los YAML.
- **Mantenibilidad**: YAML con indentacion consistente, Markdown valido.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/gl-07-02-approval-prod
```

Verifica estructura, no semantica. Compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexion

1. ¿Que pasa si el grupo `sre` tiene 0 miembros? ¿El deployment arranca igual?
2. ¿Puede el mismo usuario aprobar y lanzar el deployment? ¿Deberia?
3. ¿Como implementarias un **break-glass** (deploy urgente fuera de horario con 1 solo aprobador on-call)?
4. ¿Por que no basta con `deploy_access_levels` y hay que añadir `approval_rules`?
5. Si el equipo `sre` crece de 3 a 20 personas, ¿`required_approvals: 1` sigue teniendo sentido?

## 10. Extensiones

- Añade una tercera approval rule para `compliance` requerida solo para releases con `CI_COMMIT_TAG` que coincida con un patron SemVer-mayor.
- Modela una segunda politica para `staging` (sin approval pero con `deploy_access_levels`).
- Diseña una matriz de environments (dev/stg/prod/hotfix) con sus respectivas protecciones y documentala en el ADR como "Fase 2".

## 11. Limpieza

```bash
rm -rf /tmp/gl-07-02-approval-prod
```
