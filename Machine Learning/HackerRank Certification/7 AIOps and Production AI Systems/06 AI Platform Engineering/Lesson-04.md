# Madurez de Plataforma, Build vs Buy y Organización de Equipos

## ¿Qué es?

Un **modelo de madurez de plataforma de IA** describe las etapas por las que evoluciona la capacidad de una organización para construir, desplegar y operar sistemas de IA de forma estandarizada, segura y a escala. Es equivalente a los modelos de madurez de DevOps/MLOps (Google's MLOps Maturity, Microsoft MLOps Levels 0-2, CMMI), aplicado al conjunto más amplio **plataforma + equipos + governance**.

Un modelo típico, en 4 etapas:

| Etapa | Nombre | Síntomas | Modelos soportados | Tamaño típico |
|---|---|---|---|---|
| **1** | Ad-hoc | Cada equipo reinventa infra; notebooks en laptops; deploys manuales | 1-10 | Startup / exploración |
| **2** | Shared services básicos | Serving y monitoring centrales; training sigue custom | 10-100 | Scale-up |
| **3** | Managed platform | Self-service completo, CI/CD, registry, governance | 100-500 | Empresa mediana |
| **4** | Advanced platform | AutoML, feature store, continuous training, FinOps, platform-as-product | 500+ | Enterprise / big tech |

Cada salto cuesta típicamente **6-12 meses** de inversión focalizada y rara vez se puede saltar una etapa.

**Build vs Buy** es la decisión estratégica recurrente: construir la plataforma internamente, comprar managed (SageMaker, Vertex AI, Databricks, Azure ML, Snowflake Cortex), adoptar open-source (Kubeflow, MLflow, Metaflow, Ray) o combinar los tres (lo habitual).

## ¿Por qué importa?

Dos razones concretas:

**1. Priorización.** Saber en qué etapa estás evita invertir mal. Un equipo en etapa 1 que compra un feature store caro antes de tener serving confiable desperdicia presupuesto y no mueve KPIs. La secuencia correcta es: fundamentos → automatización → capacidades avanzadas.

**2. Expectativas realistas.** Leadership suele querer "ser como Netflix/Uber" en 6 meses. Entender que Metaflow tiene 7+ años y Michelangelo también permite negociar roadmap honesto.

Y en build vs buy, el error típico cuesta millones:

- Equipo de 15 personas construyendo plataforma desde cero → 2 años tarde, 3 ingenieros atrapados en mantenimiento, nunca alcanza la paridad de features con el managed.
- Equipo grande en SaaS caro → factura anual de $2M+ cuando construir internamente costaría la mitad y daría control.

## ¿Cómo funciona?

### Modelo de madurez detallado

```
┌─────────────────────────────────────────────────────────────────┐
│  Etapa 1: Ad-hoc                                                │
│  - Jupyter en laptop/VM, modelos entrenados "a mano"            │
│  - Deploys por SCP + screen/systemd                             │
│  - Métricas en print/CSV                                        │
│  - Sin registry, sin governance                                 │
│  Costo: bajo. Riesgo: alto. OK para prototipos y <5 modelos.    │
└─────────────────────────────────────────────────────────────────┘
            ↓ (6-12 meses + 2-3 ingenieros)
┌─────────────────────────────────────────────────────────────────┐
│  Etapa 2: Shared services básicos                               │
│  - Serving centralizado (BentoML, KServe, SageMaker Endpoints)  │
│  - Monitoring unificado (Prometheus + Grafana, Arize básico)    │
│  - Experiment tracking (MLflow, W&B)                            │
│  - Training sigue siendo custom, deploys semi-manuales          │
│  Soporta: ~50 modelos, 3-5 equipos.                             │
└─────────────────────────────────────────────────────────────────┘
            ↓ (6-12 meses + 4-6 ingenieros platform)
┌─────────────────────────────────────────────────────────────────┐
│  Etapa 3: Managed platform                                      │
│  - Self-service: cookiecutter → git push → deploy               │
│  - CI/CD completo con quality gates                             │
│  - Model Registry + Prompt Library con approvals                │
│  - Gateway LLM con virtual keys y budgets                       │
│  - SSO + RBAC + audit trails                                    │
│  - Developer Portal (Backstage/Port)                            │
│  Soporta: 100-500 modelos, 10-30 equipos.                       │
└─────────────────────────────────────────────────────────────────┘
            ↓ (12-24 meses + platform team maduro)
┌─────────────────────────────────────────────────────────────────┐
│  Etapa 4: Advanced platform                                     │
│  - Feature store (Feast, Tecton) con online + offline           │
│  - Continuous training, canary + shadow + bandit automáticos    │
│  - AutoML / HPO as a service                                    │
│  - FinOps: chargeback, forecasting, cost caps dinámicos         │
│  - Fine-tuning as a service para LLMs                           │
│  - Platform-as-product: PM dedicado, NPS, roadmap público       │
│  Soporta: 500+ modelos, 50+ equipos, enterprise AI.             │
└─────────────────────────────────────────────────────────────────┘
```

### Build vs Buy vs Open-Source

| Opción | Pros | Contras | Ejemplos |
|---|---|---|---|
| **Buy** (SaaS/managed) | Time-to-value rápido, soporte, SLA, actualizaciones gratis | Lock-in, costo creciente, customization limitada | SageMaker, Vertex AI, Databricks, Azure ML, Snowflake Cortex, Modal |
| **Open-source** | Sin licencia, flexible, comunidad, portable | Requiere expertise, mantenimiento propio, gaps enterprise | Kubeflow, MLflow, Metaflow, Ray, Kserve, Feast, Langfuse |
| **Build** | Control total, diferenciador, IP propia | Caro, lento, deuda técnica, riesgo de bus-factor | In-house glue sobre k8s |
| **Híbrido** (lo normal) | Mejor de cada mundo | Integración compleja | SageMaker + MLflow interno + gateway custom |

### Reglas de dedo (heurísticas)

```
Equipo < 10:            BUY todo. No construyas.
Equipo 10-50:           BUY core + open-source puntual.
Equipo 50-200:          Open-source + glue; evalúa híbrido con SaaS.
Equipo 200+:            Híbrido con componentes propios diferenciadores.
Diferenciador core:     BUILD esa pieza específica.
Compliance exótico:     BUILD o adopta OSS self-hosted.
Multi-cloud obligado:   OSS portable (Kubeflow, Ray, MLflow).
```

### Total Cost of Ownership (TCO)

Comparar precio de lista es engañoso. TCO real = **licencia + infra + personas + oportunidad**.

```
TCO_build  = infra + N_ing × salario_cargado × años + feature-lag_lost_revenue
TCO_buy    = licencia + infra_marginal + 0.5-1 ing (ops) + lock-in_tax
TCO_oss    = infra + 1-2 ing (mantenimiento) + contribución comunidad
```

Ejemplo numérico:

| Opción | Año 1 | Año 3 (acumulado) |
|---|---|---|
| Databricks (equipo 30) | $200k licencia + $100k infra + 1 ing ($200k) = $500k | ~$1.6M |
| Build desde cero | $50k infra + 3 ing ($600k) = $650k | ~$2.5M + 18 meses atraso |
| OSS híbrido (MLflow + Ray + KServe + Langfuse) | $100k infra + 2 ing ($400k) = $500k | ~$1.6M, portable |

### Organización de equipos

| Tamaño org | Platform team | Ratio DS:platform | Estructura |
|---|---|---|---|
| < 50 personas | 1-2 ingenieros embebidos en producto | 1:10 | No hay platform team dedicado |
| 50-200 | 3-5 ingenieros platform | 1:15 | Equipo dedicado, PM a tiempo parcial |
| 200-1000 | 10-20, con especialización (infra, DX, security, FinOps) | 1:20 | Platform team + enabling teams |
| 1000+ | 50+, estructura federada | 1:25 | Platform + stream-aligned + enabling + complicated-subsystem (Team Topologies) |

### Modelo Team Topologies aplicado a IA

- **Platform team**: construye y opera la plataforma (serving, registry, gateway, feature store).
- **Stream-aligned team**: equipo de producto (ej. "team recomendaciones") que consume la plataforma.
- **Enabling team**: ML engineers que embajadores que ayudan a product teams a adoptar la plataforma.
- **Complicated-subsystem team**: especialistas en algo profundo (ej. inference optimization, RLHF).

### Métricas de éxito de plataforma

| Métrica | Qué mide | Target maduro |
|---|---|---|
| **Adoption rate** | % equipos usando la plataforma | > 80% |
| **Time to First Deployment** | Nuevo team → modelo en prod | < 1 semana |
| **Deployment frequency** | Deploys / modelo / mes | > 2 |
| **Lead time for change** | Commit → prod | < 1 día |
| **Change failure rate** | % deploys que generan rollback | < 15% |
| **MTTR** | Tiempo medio de recuperación | < 1h |
| **Platform NPS** | Satisfacción de usuarios internos | > 40 |
| **Cost per inference** | $/1k requests | Baja o estable |
| **% capacity on maintenance** | Dedicación a deuda técnica | 20-30% |

### Future-proofing

- **Modularidad**: componentes reemplazables (hoy LiteLLM, mañana Portkey; hoy MLflow, mañana otro) a través de interfaces estables.
- **API versioning**: contratos congelados con deprecation window ≥ 6 meses.
- **Multi-framework**: no forzar un solo stack (PyTorch, JAX, scikit, transformers coexisten).
- **Multi-cloud ready**: abstracciones sobre compute (Ray, Kubernetes).
- **Innovation budget**: 10-20% de capacidad en experimentación.
- **Succession planning**: nada vive en una sola cabeza; docs, ADRs, grabaciones.

## Ejemplo con código

### 1. Scorecard de madurez (self-assessment ejecutable)

```python
from dataclasses import dataclass, field

CAPABILITIES = {
    "stage_1": [
        ("serving_centralized",  "Existe un servicio compartido de serving"),
        ("experiment_tracking",  "Hay tracking centralizado (MLflow/W&B)"),
        ("basic_monitoring",     "Métricas básicas por modelo (latencia, errores)"),
    ],
    "stage_2": [
        ("model_registry",       "Registry central con stages"),
        ("ci_cd_pipeline",       "CI/CD estandarizado para modelos"),
        ("secrets_management",   "Secrets en Vault/KMS, no en código"),
        ("sso",                  "Login único para toda la plataforma"),
    ],
    "stage_3": [
        ("self_service_deploy",  "Un equipo nuevo despliega en < 1 semana"),
        ("prompt_library",       "Prompts versionados con labels"),
        ("rbac_granular",        "Permisos por rol y por recurso"),
        ("cost_chargeback",      "Chargeback automático por equipo"),
        ("audit_trail",          "Audit append-only de cambios"),
        ("llm_gateway",          "Gateway con virtual keys y budgets"),
    ],
    "stage_4": [
        ("feature_store",        "Feature store online + offline consistente"),
        ("continuous_training",  "Retrain automático al detectar drift"),
        ("canary_automated",     "Canary + shadow automáticos"),
        ("autoscaling_gpu",      "Autoscaling de GPUs con bin-packing"),
        ("platform_pm",          "Platform team con PM y NPS medido"),
        ("finops_dashboards",    "FinOps con forecasting y alertas"),
    ],
}

@dataclass
class Assessment:
    answers: dict = field(default_factory=dict)

    def score(self):
        reached = []
        for stage, caps in CAPABILITIES.items():
            if all(self.answers.get(c, False) for c, _ in caps):
                reached.append(stage)
        return max([int(s.split("_")[1]) for s in reached] or [0])

    def gaps(self, target: int):
        key = f"stage_{target}"
        return [(c, desc) for c, desc in CAPABILITIES[key]
                if not self.answers.get(c, False)]

a = Assessment(answers={
    "serving_centralized": True, "experiment_tracking": True,
    "basic_monitoring": True, "model_registry": True,
    "ci_cd_pipeline": True, "secrets_management": True, "sso": False,
})
print("Etapa alcanzada:", a.score())
print("Gaps para etapa 2:", a.gaps(2))
```

### 2. TCO estimator (build vs buy vs OSS)

```python
from dataclasses import dataclass

@dataclass
class Scenario:
    name: str
    license_year: float
    infra_year: float
    engineers: float
    salary_loaded: float = 200_000   # cargado (comp + overhead)
    feature_lag_months: float = 0    # meses de atraso vs mercado
    revenue_per_month: float = 0     # ingresos "en riesgo" por el lag

    def tco(self, years: int) -> float:
        base = (self.license_year + self.infra_year
                + self.engineers * self.salary_loaded) * years
        opportunity = self.feature_lag_months * self.revenue_per_month
        return base + opportunity

scenarios = [
    Scenario("Databricks (buy)",   license_year=200_000, infra_year=100_000,
             engineers=1,  feature_lag_months=0, revenue_per_month=0),
    Scenario("OSS híbrido",        license_year=0,       infra_year=120_000,
             engineers=2,  feature_lag_months=3, revenue_per_month=50_000),
    Scenario("Build desde cero",   license_year=0,       infra_year=80_000,
             engineers=4,  feature_lag_months=12, revenue_per_month=50_000),
]

for s in scenarios:
    print(f"{s.name:<22} TCO 3 años = ${s.tco(3):,.0f}")
```

### 3. Backstage: catálogo de recursos de la plataforma

```yaml
# catalog-info.yaml  (checked-in en el repo del modelo)
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: fraud-txn-xgb
  description: Modelo de scoring de fraude transaccional
  annotations:
    mlflow.org/model-uri: models:/risk/fraud-txn-xgb/Production
    langfuse.io/project: risk
    pagerduty.com/service-id: PXYZ123
  tags: [risk, pii, high-criticality]
spec:
  type: ml-model
  lifecycle: production
  owner: team-risk
  system: fraud-platform
  dependsOn:
    - resource:feature-store/transactions-online
    - component:feature-pipeline-transactions
```

### 4. Políticas OPA/Rego: enforcement en el pipeline

```rego
package platform.deploy

default allow = false

allow {
    input.target_stage == "Staging"
    input.user.role == "ds"
}

allow {
    input.target_stage == "Production"
    count(input.approvals) >= 2
    some i; input.approvals[i].role == "ml_lead"
    input.checks.evals.passed == true
    input.checks.security_scan.passed == true
    not input.model.pii_touching    # modelos con PII requieren DPIA
}
```

### 5. Rotación platform ↔ product (embedding)

Patrón: cada trimestre, 1 ingeniero de platform pasa 6 semanas embebido en un product team. Recoge pain points, documenta nuevos golden paths y vuelve con backlog.

### 6. Matriz build vs buy por componente

| Componente | Default | Cuándo build |
|---|---|---|
| Compute / orquestación | Buy (k8s managed, Ray, Modal) | Nunca |
| Registry | OSS (MLflow) | Casi nunca |
| LLM gateway | OSS (LiteLLM) + glue | Si tienes requisitos únicos de routing/compliance |
| Prompt library | OSS (Langfuse) o SaaS | Nunca |
| Feature store | OSS (Feast) o Buy (Tecton) | Si tienes patrones muy particulares de tiempo real |
| Developer portal | OSS (Backstage) | Nunca |
| Observabilidad | Buy (Datadog LLM Obs, Arize) | Casi nunca |
| Governance / cost | Build el "glue" sobre OSS | Es tu diferenciador |

## Errores comunes

- **Querer saltar etapas.** "Vamos directo a feature store + continuous training" sin serving confiable → explota en producción. Cada etapa habilita la siguiente.
- **Confundir madurez con herramientas.** Comprar Databricks no te hace etapa 3; sin golden paths, approvals y cultura, sigues en etapa 1 con factura cara.
- **Build desde cero sin diferenciador.** Reconstruir MLflow o KServe "pero mejor" quema años. Reserva el build para la pieza que es ventaja competitiva.
- **Comparar sólo licencias.** Olvidar personas, oportunidad y lock-in. TCO real incluye los 4.
- **Platform team sin PM.** El backlog deriva a lo "técnicamente interesante" en lugar de a lo que mueve adopción. Un PM dedicado paga su salario en meses.
- **Ratio platform:DS mal calibrado.** Menos de 1:25 es insuficiente (quema), más de 1:10 es despilfarro.
- **No rotar platform ↔ product.** La platform se desconecta de usuarios reales; construye sueños de ingeniero que nadie necesita.
- **0% capacidad para mantenimiento.** La plataforma se vuelve frágil, los incidentes crecen, la deuda ahoga el roadmap. Reserva 20-30%.
- **Métricas de vanidad.** "Lanzamos 15 features este trimestre" sin medir adopción ni NPS. Lo único que importa: ¿los equipos la usan y están contentos?
- **Lock-in sin salida.** Firmar 3 años con un vendor sin cláusula de salida ni plan de portabilidad. Un cambio estratégico te deja atrapado.
- **Innovar sin budget protegido.** Sin 10-20% para R&D, la plataforma envejece y queda obsoleta frente a lo que publica Netflix/Uber/Spotify.
- **Succesion planning cero.** Toda la plataforma vive en la cabeza de 1 staff engineer. Cuando se va, se cae el castillo.

## Resumen

- La **madurez** evoluciona en 4 etapas (**ad-hoc → shared services → managed → advanced**), con 6-12 meses por salto; no se puede saltar etapas.
- La priorización depende de la etapa: fundamentos primero (serving, monitoring, registry), capacidades avanzadas después (feature store, continuous training, FinOps).
- **Build vs buy vs OSS** se decide por tamaño, criticidad, diferenciación y TCO; la mayoría acaba en **híbrido**.
- Reglas de dedo: < 10 personas compra todo; 10-50 compra core + OSS; 50-200 OSS + glue; 200+ híbrido con piezas propias donde hay ventaja competitiva.
- Las referencias públicas (Netflix Metaflow, Uber Michelangelo, LinkedIn Pro-ML, Spotify ML Platform, Airbnb Bighead) tienen 5-10+ años de inversión; no se replican en 6 meses.
- **Team Topologies** encaja: platform team + stream-aligned (producto) + enabling (ML engineers) + complicated-subsystem (expertise profundo).
- Métricas que importan: **adoption**, **Time to First Deployment**, **deployment frequency**, **MTTR**, **NPS** interno, **cost/inference**.
- **Future-proofing** = modularidad, API versioning, multi-framework, innovation budget 10-20% y succession planning real.
- Los errores más caros: saltar etapas, build sin diferenciador, comparar sólo licencias, platform sin PM y 0% capacidad para mantenimiento.
