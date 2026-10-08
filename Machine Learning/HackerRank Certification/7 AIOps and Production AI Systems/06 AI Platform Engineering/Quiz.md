# Quiz: AI Platform Engineering

Tu organización tiene 15 data scientists en 3 equipos desplegando 30 modelos. Cada equipo construyó infraestructura custom para training y serving. El deploy toma 2 semanas por modelo debido a procesos manuales. Los modelos tienen monitoring inconsistente. Leadership quiere mejorar velocidad y estandarización.

---

### 1. Los equipos pasan el 40% de su tiempo en infraestructura en vez de en modelos. ¿Qué enfoque de plataforma deberías tomar?

- Usar una plataforma comercial como SageMaker o Vertex AI para time-to-value rápido. ✅
- Construir una plataforma custom desde cero adaptada a necesidades exactas.
- Continuar con infraestructura custom por equipo para mantener flexibilidad.
- Contratar 10 platform engineers para construir y mantener infraestructura custom.

**Explicación:** Para una organización de 15 data scientists y 30 modelos no hay volumen suficiente para justificar construir una plataforma propia (TCO desfavorable y time-to-value de 12-24 meses). Las plataformas comerciales (SageMaker, Vertex AI, Databricks, Azure ML) proveen capacidades maduras en semanas: registry, serving, monitoring, CI/CD, governance. En términos de madurez, saltas de etapa 1-2 a etapa 3 sin construir desde cero. Mantener custom por equipo perpetúa la duplicación y la inconsistencia; contratar 10 ingenieros gasta ~$2M/año en algo que ya existe. La regla de dedo "< 50 personas = buy" aplica aquí; en etapas posteriores podrás evaluar híbrido u OSS si aparece un diferenciador real.

---

### 2. A veces se despliegan modelos a producción sin validación adecuada, causando incidentes. ¿Qué mecanismo de governance aborda esto?

- Automatización de deploy más rápida para reducir errores manuales.
- Entrenamiento más completo para data scientists en deploy.
- Timelines de deploy más largos para permitir más revisión manual.
- Model registry con approval workflows requiriendo validación antes de producción. ✅

**Explicación:** El problema es ausencia de **control previo a producción**, no de velocidad ni de capacitación. Un **model registry con approval workflows** (MLflow + webhooks, Vertex Model Registry, SageMaker Model Registry) convierte la promoción Dev → Staging → Production en un evento auditable que exige: (a) checks automáticos (performance mínimo, no regresión vs modelo actual, scans de seguridad, bias por grupo, PII); (b) aprobación humana con contexto (métricas comparativas, test results, plan de rollout). Hacer el deploy más rápido sin gate empeora el problema. Alargar timelines manuales no escala y degrada velocidad sin resolver la raíz. La capacitación ayuda, pero no reemplaza controles sistemáticos. Approval workflows combinan automatización y juicio humano, que es el patrón estándar en organizaciones maduras.

---

### 3. Tu plataforma procesará datos de clientes de la UE incluyendo nombres y emails. GDPR requiere borrado de datos de usuarios específicos bajo petición. ¿Cómo debería la plataforma manejar esto?

- Almacenar todos los datos sin detección de PII ya que los data scientists necesitan acceso completo.
- Bloquear todos los datos de clientes de la UE de la plataforma para evitar compliance de GDPR.
- Implementar detección de PII, opciones de anonimización y procedimientos de deletion request. ✅
- Borrar todos los datos de training semanalmente para minimizar retención de PII.

**Explicación:** GDPR exige **data minimization**, **lawful basis**, **right of access** y **right to erasure (Art. 17)**. El cumplimiento requiere un pipeline end-to-end: (1) **detección automática** con Presidio/Comprehend/Macie antes de ingesta; (2) **clasificación** por sensibilidad; (3) **anonimización/pseudonimización** (hashing, tokenization, masking, generalización, differential privacy) con balance privacidad/utilidad; (4) **access control** granular (RBAC + row/column-level) con audit; (5) **procedimientos de erasure** que recorran OLTP, data lake, feature store (online y offline), logs, trazas de LLM y, cuando aplica, decisión documentada sobre retraining del modelo. Acceso ilimitado a PII viola el principio de mínimo privilegio y expone a multas de hasta 4% de revenue global. Bloquear datos UE sacrifica el mercado europeo. Borrar semanalmente no satisface erasure específico por usuario y rompe utilidad del modelo. La solución es el ciclo completo documentado y auditado.

---

### 4. Tu organización tiene infraestructura de serving compartida pero los equipos aún construyen pipelines de training custom y procesos de deploy manuales. ¿En qué etapa de madurez estás?

- Etapa 1: Ad-hoc (sin infraestructura compartida).
- Etapa 2: Shared services básicos (algo de centralización, mucho trabajo manual). ✅
- Etapa 3: Managed platform (automatización completa y self-service).
- Etapa 4: Advanced platform (escala enterprise con features avanzadas).

**Explicación:** La descripción encaja exactamente en **etapa 2**: existen **shared services básicos** (serving centralizado, posiblemente monitoring) pero capacidades críticas (training, CI/CD, deploy) siguen siendo **custom por equipo** y **manuales**. En etapa 1 no habría ni siquiera serving compartido. Etapa 3 requiere **self-service completo**: cualquier equipo nuevo despliega en < 1 semana vía `git push` con CI/CD estandarizado, model registry con approvals, prompt library, SSO, RBAC y audit trail. Etapa 4 añade feature store, continuous training, canary automático, FinOps y platform-as-product con PM dedicado y NPS medido. Saltar directo a etapa 3 o 4 sin consolidar etapa 2 suele fallar: construir feature store o AutoML sobre serving inestable produce incidentes constantes. El camino correcto es inversión focalizada de 6-12 meses para pasar a etapa 3 (automatizar training + CI/CD + registry + self-service), midiendo adopción y Time to First Deployment como KPIs.

---

### 5. Tu organización creció de 15 a 60 data scientists en 10 equipos. Los 2 platform engineers originales están saturados. ¿Cómo debes ajustar la estructura del platform team?

- Mantener 2 platform engineers pero mejorar su productividad con mejores herramientas.
- Disolver el platform team y distribuir ingenieros entre product teams.
- Contratar 20 platform engineers para asegurar cobertura completa.
- Crecer a 5-6 platform engineers y establecer roles especializados. ✅

**Explicación:** La heurística de la industria para ratio **DS:platform-engineer** es **1:10 a 1:15**. Con 60 data scientists necesitas **4-6 platform engineers**, y a este tamaño la **especialización** empieza a pagar: un rol en infra/compute, uno en developer experience y portal, uno en security/compliance, uno en LLM gateway y observabilidad, uno en MLOps/registry. Esto permite golden paths más profundos y menos context switching. Mantener solo 2 ingenieros con "mejores herramientas" no escala y lleva a burnout, backlog explosivo y degradación de SLO. Disolver el equipo elimina ownership central y vuelve a fragmentar la plataforma (regreso a etapa 1-2) con duplicación por equipo. Contratar 20 es sobredimensionar: ratio 1:3 convierte al platform team en consultores sin backlog propio, infla costos y crea procesos burocráticos. Además de crecer, debes introducir prácticas como **embedding** (rotar platform engineers con product teams), **PM de plataforma**, **métricas de NPS/adopción** y reservar 20-30% de capacidad a mantenimiento y 10-20% a innovación.
