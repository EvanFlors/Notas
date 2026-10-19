# Ejemplo 01 — RBAC con Role-based Authorization Strategy en JCasC

> Lectura y análisis. Sin ejecución. Objetivo: leer un `jenkins.yaml` y saber qué puede hacer cada grupo.

## 1. Escenario

Empresa con 3 colectivos de uso del controller:

- **`jenkins-admins`** — plataforma; dueños del controller.
- **`team-a`** — equipo de producto A; jobs bajo el folder `team-a/`.
- **`team-b`** — equipo de producto B; jobs bajo el folder `team-b/`.
- **`all-staff`** — resto de la empresa; solo lectura global.

## 2. YAML anotado

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin-bootstrap"
          password: "${ADMIN_BOOTSTRAP_PASSWORD}"

  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            description: "Platform team; full control of the controller."
            permissions:
              - "Overall/Administer"
            entries:
              - group: "jenkins-admins"

          - name: "readonly-everyone"
            description: "Read-only across controller for all staff."
            permissions:
              - "Overall/Read"
              - "View/Read"
              - "Job/Read"
            entries:
              - group: "all-staff"

        items:
          - name: "team-a-maintainers"
            description: "team-a owns everything under team-a/*."
            pattern: "^team-a/.*"
            permissions:
              - "Job/Build"
              - "Job/Configure"
              - "Job/Read"
              - "Job/Workspace"
              - "Job/Cancel"
              - "Credentials/View"
            entries:
              - group: "team-a"

          - name: "team-b-maintainers"
            pattern: "^team-b/.*"
            permissions:
              - "Job/Build"
              - "Job/Configure"
              - "Job/Read"
              - "Job/Workspace"
              - "Job/Cancel"
              - "Credentials/View"
            entries:
              - group: "team-b"
```

## 3. Lectura — qué puede hacer cada grupo

| Grupo | Fuera de su folder | En `team-a/*` | En `team-b/*` |
|-------|--------------------|---------------|---------------|
| `jenkins-admins` | Todo (Overall/Administer) | Todo | Todo |
| `team-a` | Nada (sin rol global) | Build, Configure, Read, Cancel, Workspace, Credentials/View | Nada |
| `team-b` | Nada | Nada | Mismo que team-a en su folder |
| `all-staff` | Read-only (Jobs y Views) | Read-only | Read-only |
| `anonymous` | **Nada** (no asignado) | Nada | Nada |

## 4. Qué está haciendo bien este YAML

1. **Roles a grupos**, no a usuarios individuales. Cuando alguien cambie de equipo, el IdP mueve su grupo; aquí nada que tocar.
2. **Patrón regex por folder** (`^team-a/.*`), no por job individual. Un job nuevo del team-a hereda permisos automáticamente.
3. **`anonymous` no aparece** → cero permisos. Nadie sin login lee nada.
4. **`admin-bootstrap`** existe solo con password desde env (`${...}`). En prod, la DB local se desactiva una vez el SSO funciona.
5. **Scopes explícitos**: `all-staff` tiene `Overall/Read` pero **no** `Job/Build` — pueden ver, no ejecutar.

## 5. Errores típicos a evitar en este tipo de YAML

- Añadir `Job/Build` a `readonly-everyone` "para que los QA puedan reintentar builds": crea un rol que no es ni readonly ni developer. Mejor crear `qa-rerun` con alcance explícito.
- Dar `Overall/Administer` al grupo `developers` "temporalmente". Nunca es temporal.
- Patrón `.*` en un project role: equivale a global; usa un global role.
- Olvidar `View/Read` para los readonly: la UI aparece casi vacía y la gente escala pidiendo "más permisos" sin razón real.

## 6. Para profundizar

- Lista completa de permisos: `Manage Jenkins → Security → Authorization → Role-based Strategy → Add global role`.
- Documentación oficial del plugin: `https://plugins.jenkins.io/role-strategy/`.
- `jenkins.yaml` → ver sección 3 de la lección (`theory/lesson.md`).
