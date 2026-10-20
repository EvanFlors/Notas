# Ejemplo 02 — Matriz de gating por plan (Free / Premium / Ultimate)

> Objetivo: entender qué features clave están **gated** por plan y por qué eso puede ser **el factor dominante** en la decisión de plataforma. **Verificar vigencia en Fase 4**: GitLab reorganiza el gating varias veces por año.

## 1. Matriz (vista para toma de decisión, no exhaustiva)

| Área | Feature | Free | Premium | Ultimate |
|------|---------|------|---------|----------|
| CI/CD básico | `.gitlab-ci.yml`, stages, jobs, needs, matrix | ✅ | ✅ | ✅ |
| CI/CD básico | CI/CD Components + Catalog | ✅ (consumo); publicación con límites | ✅ | ✅ |
| CI/CD básico | Minutos de SaaS runners incluidos | tier limitado | más minutos | más minutos |
| Runners | Group / Project Runners self-hosted | ✅ | ✅ | ✅ |
| Variables / Secrets | Group variables, protected/masked | ✅ | ✅ | ✅ |
| Variables / Secrets | External Secrets (Vault / AWS SM / GCP SM) via `secrets:` | ❌ | ✅ | ✅ |
| OIDC | ID Tokens | ✅ | ✅ | ✅ |
| MR / Review | MR básicas, approvals opcionales | ✅ | ✅ | ✅ |
| MR / Review | **Multiple approval rules** (p. ej. "Security + Owner") | ❌ | ✅ | ✅ |
| MR / Review | Code Owners obligatorios en MR | ❌ (parcial) | ✅ | ✅ |
| Environments | Environment básico + URL | ✅ | ✅ | ✅ |
| Environments | **Protected environments con approval rules** | ❌ (parcial) | ✅ | ✅ |
| Environments | Review Apps | ✅ | ✅ | ✅ |
| Security (SAST) | SAST para algunos lenguajes | ✅ | ✅ | ✅ (todos los lenguajes + reglas avanzadas) |
| Security (Secret Detection) | Secret Detection | ✅ | ✅ | ✅ (+ post-filtering) |
| Security | **DAST** (dynamic) | ❌ | ❌ | ✅ |
| Security | **Dependency Scanning (SCA)** | ❌ | ❌ | ✅ |
| Security | **Container Scanning** avanzado | ❌ | ❌ | ✅ |
| Security | **IaC Scanning** (Terraform, CFN, K8s) | ❌ | ❌ | ✅ |
| Security | **License Scanning** | ❌ | ❌ | ✅ |
| Security | **Fuzz Testing** | ❌ | ❌ | ✅ |
| Security | **Security Dashboard** agregado | ❌ | ❌ | ✅ |
| Compliance | **Compliance Pipeline / Framework** | ❌ | ❌ | ✅ |
| Compliance | **Audit Events** (streaming a SIEM) | ❌ | parcial | ✅ |
| Governance | SAML SSO | parcial | ✅ | ✅ |
| Governance | SCIM | ❌ | ✅ | ✅ |
| Governance | **Portfolio / Epics / OKRs** | ❌ | ✅ | ✅ (más niveles) |
| Package Registry | Container Registry, Package Registry (PyPI/npm/...) | ✅ | ✅ | ✅ |
| Dependency Proxy | Dependency Proxy (cache de Docker Hub) | ✅ | ✅ | ✅ |

> **Importante**: esta tabla es una **vista de decisión**, no un contrato. GitLab reclasifica features entre planes con cierta frecuencia; verifica la vigencia en la página oficial de pricing antes de defender una ADR.

## 2. Comparación con GitHub

| Feature equivalente | GitHub | GitLab |
|---------------------|--------|--------|
| Workflows + runners | Free / Pro / Team | Free |
| Composición y reuso | Free (reusable workflows) | Free (`include:`/`extends:`); Components publicables en todos los planes con matices |
| OIDC a cloud | Free | Free |
| SAML SSO | Enterprise Cloud | Premium |
| SCIM | Enterprise Cloud | Premium |
| Required workflows | Enterprise | Compliance Pipeline (Ultimate) |
| Code scanning (CodeQL) | **GHAS** (addon) | SAST (parcial Free; completo Ultimate) |
| Secret scanning | **GHAS** (addon) | Secret Detection (Free parcial; Ultimate completo) |
| Supply chain / Dependabot | Free (Dependabot alerts/updates) | Dependency Scanning + Container Scanning (Ultimate) |
| Dashboards de seguridad | GHAS | Ultimate |

## 3. Qué debe quedar en el ADR

Un ADR serio de "GHA vs GitLab" **no** compara "Free vs Free": compara los *packages reales* para tu necesidad:

- **Para una org pequeña sin compliance formal**: Free vs Free es razonable. GHA probablemente gana por ecosistema de Marketplace.
- **Para una org con compliance (SOC 2 / PCI / HIPAA / ISO 27001)**: comparar **GitLab Ultimate** vs **GitHub Team + GHAS + GHE Cloud**. Ambos cuestan dinero real; el eje de decisión es *integración/UX*, no sticker price.
- **Para air-gap o Self-Managed gratuito**: GitLab CE no tiene competencia en GitHub.

## 4. Trampas comunes

1. **Suponer que SAST Free = Ultimate**. En Free hay SAST, pero con reglas y lenguajes limitados; el dashboard agregado y la triage multi-vuln no están.
2. **Olvidar que GHAS se cobra por "committer activo"**, no por seat. Puede resultar más barato o más caro que Ultimate dependiendo de la ratio dev/mes.
3. **Ignorar que Compliance Framework (Ultimate) sustituye un montón de glue scripts** que en GHA harías manual para enforzar un workflow obligatorio por repo con etiqueta.
4. **Suponer que Review Apps es Ultimate**. No lo es — están desde Free. Pero las **protected environments con approval rules** sí requieren plan superior.

Reflexión obligatoria antes del ADR: ¿cuál es el **plan equivalente real** en el que vas a comparar?
