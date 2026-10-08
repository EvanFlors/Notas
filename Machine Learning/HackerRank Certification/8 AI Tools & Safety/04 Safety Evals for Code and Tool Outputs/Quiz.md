# Quiz: Safety Evals para Código y Tool Outputs

Tu equipo usa IA para generar código, scripts y cambios de configuración, y para orquestar agentes con tools. Necesitas prevenir regresiones de seguridad, violaciones de licencias, APIs alucinadas, abuso de tools e incidentes operacionales **antes** de que lleguen a producción, y detectarlos rápido cuando se escapen.

---

**1. ¿Por qué los cambios de código asistidos por IA necesitan safety evals dedicadas?**

- Los problemas de seguridad siempre aparecen como fallas en los tests funcionales.
- La IA incrementa el volumen de cambios y amplifica patrones inseguros predecibles. **Correcto**
- Las safety evals reemplazan al code review manual.
- Las safety evals solo se necesitan después de un incidente.

**Explicación:** Los asistentes de IA generan decenas de PRs por día replicando patrones del OWASP Top 10 (SQL injection, logging de secretos, auth faltante). El review humano no escala a ese volumen y naturalmente se enfoca en funcionalidad, no en seguridad. Las safety evals (SAST con Semgrep/Bandit, SCA, secrets scanning, policy checks) atrapan automáticamente lo que el reviewer humano pierde. No reemplazan al review ni a los tests: son una **capa complementaria** específica para seguridad.

---

**2. ¿Qué control reduce mejor el riesgo de licencias y seguridad de las dependencias?**

- Permitir cualquier dependencia para acelerar los cambios.
- Usar allowlists de dependencias y escaneo de licencias en CI. **Correcto**
- Escanear dependencias solo después del release.
- Depender de review manual para todo cambio de dependencia.

**Explicación:** Las dependencias son el vector #1 de supply-chain attacks (incidentes como event-stream, colors.js, xz-utils). Un allowlist combinado con escáneres automáticos (**Snyk**, **Safety**, **npm audit**, **Dependabot**) y una matriz de compatibilidad de licencias (permissive / weak copyleft / strong copyleft / restricted) ejecutada en CI previene que lleguen al main dependencias con CVEs conocidos o licencias incompatibles con tu modelo de distribución (GPL en producto propietario).

---

**3. ¿Cuál es el control más confiable contra APIs alucinadas?**

- Aumentar la creatividad del modelo.
- Fundamentar los outputs en documentación actual y verificar con compilación/tests. **Correcto**
- Solo revisar el código visualmente.
- Saltarse la verificación para moverse más rápido.

**Explicación:** Las alucinaciones de API (funciones inexistentes, argumentos deprecados, keys de configuración inventadas) son el resultado de modelos entrenados con información desactualizada. La defensa de dos capas: (1) **grounding** con retrieval de docs actuales de la API o schema generado desde código, y (2) **verification gates** automáticos (compilación, type checks, unit tests, contract tests, schema validators). Juntos atrapan APIs inexistentes antes del merge; aumentar temperatura o skippear verificación empeora el problema.

---

**4. ¿Cuál es el mejor ejemplo de un test de regresión de seguridad?**

- Un test que verifica solo reglas de formato.
- Un test que falla si falta auth middleware en rutas protegidas. **Correcto**
- Un test que cuenta cuántas líneas cambiaron.
- Un test que verifica solo errores de sintaxis.

**Explicación:** Un buen security regression test refleja un **incidente real** del equipo. "Falla si rutas `/api/admin/*` o `/api/internal/*` no tienen `@require_auth`" previene exactamente la clase de bug que ya ocurrió (ej. endpoint sin middleware mergeado por un reviewer que se enfocó en funcionalidad). Los tests genéricos (formato, syntax, LOC) no previenen regresiones de seguridad; los tests específicos atados a incidentes históricos sí.

---

**5. ¿Cuál es la primera prioridad durante un incidente de herramienta de IA?**

- Escribir un postmortem detallado.
- Contener el blast radius deshabilitando acciones riesgosas. **Correcto**
- Aumentar la temperatura del modelo para reducir repetición.
- Ignorar el incidente hasta que un cliente lo reporte.

**Explicación:** Los incidentes de IA se propagan más rápido que los tradicionales porque la herramienta genera patrones consistentes en muchos PRs simultáneamente. La prioridad #1 es **containment**: activar el kill switch (modo `read_only`, `limited` o `blocked`), bloquear nuevos merges asistidos por IA, parar la propagación. **Diagnóstico y postmortem vienen después** del containment. Severidades SEV-1 (data exposure, outage) requieren response < 15 min; SEV-2 (patrón inseguro masivo) < 1 hora.

---

**6. ¿Por qué el desarrollo asistido por IA incrementa el riesgo de licencias?**

- Los outputs de IA siempre son ilegales de usar.
- La IA puede generar código sin provenance claro, saltándose los chequeos usuales. **Correcto**
- El licensing solo aplica a proyectos open-source.
- El licensing es irrelevante para herramientas internas.

**Explicación:** Un asistente puede generar un snippet que se parece a código con licencia GPL sin que el desarrollador lo sepa. Sin **provenance tracking** (de dónde viene el código), es imposible probar compliance ante una auditoría o demanda. La solución: SBOM automático, similarity checks contra corpora open-source conocidos, allowlists de licencias, y preguntas explícitas en el template de PR ("¿Se generó algún snippet grande? ¿Qué fuente verificaste?"). Internal tools tienen más flexibilidad, pero al momento de distribuir externamente el riesgo se materializa.

---

**7. ¿Por qué deben evaluarse las salidas no-código (configs, scripts)?**

- Son de bajo riesgo comparadas con el código.
- Pueden cambiar la postura de seguridad y el comportamiento de infraestructura. **Correcto**
- No afectan producción.
- Siempre son generadas por humanos.

**Explicación:** Las configs de Kubernetes, Terraform, CI/CD, feature flags y variables de entorno **definen las fronteras de seguridad** del sistema: ACLs, egress rules, service accounts, secrets mount points. Un IaC con `0.0.0.0/0` en un security group, un deployment con `privileged: true`, o un script de build con `curl | bash` desde un host no verificado pueden abrir vulnerabilidades críticas. Herramientas como **Checkov**, **tfsec**, **kube-score** y **Semgrep** escanean estos artefactos con el mismo rigor que el código aplicativo.

---

**8. En safety evals adversariales, ¿qué métrica dual debes reportar siempre?**

- Solo el Attack Success Rate (ASR).
- ASR junto con over-refusal rate. **Correcto**
- Solo la perplejidad del modelo.
- Solo la latencia promedio.

**Explicación:** Optimizar solo ASR produce un modelo que rechaza todo (seguro pero inútil); optimizar solo utilidad produce un modelo permisivo (útil pero inseguro). La **frontera de Pareto** se mide con ambas métricas. Benchmarks como **StrongREJECT** y **XSTest** están diseñados específicamente para medir over-refusal. Un modelo con ASR 0.5% y over-refusal 2% es mejor producto que uno con ASR 0.5% y over-refusal 30%, incluso si en jailbreak son equivalentes.

---

**9. Si usas un LLM-as-judge para evaluar safety, ¿qué buena práctica aplica?**

- Usar el mismo modelo generador como juez para consistencia.
- Usar un modelo distinto al generador y calibrar su correlación con humanos. **Correcto**
- Confiar siempre en el juez sin validación humana.
- Usar temperatura alta en el juez para más variedad.

**Explicación:** Un juez de la **misma familia** que el generador tiene el mismo bias y produce auto-afirmación (estudios muestran 10-15% más "safe" que humanos). Best practice: (1) juez de familia distinta (ej. generador Claude, juez GPT-4 o Llama Guard, o viceversa), (2) **rubric estructurado** con criterios binarios o Likert cortos, (3) **calibrar inter-rater agreement** con humanos (Cohen's κ > 0.6 aceptable), (4) temperatura 0 en el juez, (5) few-shot con disagreement cases. Un juez descalibrado es peor que no tener juez porque genera falsa confianza.

---

**10. ¿Cuál es el riesgo distintivo de los **agentes** con tools, respecto a chatbots puros?**

- Son más lentos.
- Pueden ejecutar acciones destructivas, exfiltrar datos y encadenar tools inocuos en resultados dañinos. **Correcto**
- Siempre usan menos tokens.
- Nunca son vulnerables a prompt injection.

**Explicación:** Un chatbot inseguro genera texto peligroso; un agente inseguro **ejecuta** acciones en el mundo real: borra tablas, transfiere dinero, envía correos, llama APIs externas. Según **OWASP LLM Top 10 (LLM07 Insecure Plugin Design, LLM08 Excessive Agency)** y benchmarks como **AgentHarm** e **InjecAgent**, los riesgos específicos son: destructive actions, data exfiltration, privilege escalation, prompt injection indirecto vía documentos leídos por tools, y confused deputy. La defensa requiere 4 anillos: **scoping** (least privilege), **pre-call policy**, **sandboxing**, **post-call audit**. Toda acción destructiva o con costo monetario debe tener **HITL** por default.

---

**11. ¿Cuál es la razón principal para no usar solo benchmarks públicos (HarmBench, AgentHarm) para evaluar safety?**

- Son demasiado difíciles.
- Los modelos nuevos pueden haberlos memorizado durante el training. **Correcto**
- No tienen suficientes ejemplos.
- Solo cubren inglés.

**Explicación:** Cualquier eval set publicado en GitHub o papers está en el training data de los modelos siguientes (contaminación). Un modelo puede obtener 99% en HarmBench no porque sea seguro sino porque **memorizó las respuestas correctas**. Best practice: (1) mantener un **held-out private set** rotado trimestralmente, (2) generar continuamente nuevos adversariales con red teaming automatizado (**PAIR**, **TAP**, **GCG**, **GPTFuzz**), (3) reportar en benchmarks públicos *y* privados para detectar overfitting a benchmarks.

---

**12. En continuous safety monitoring, ¿qué garantiza que el programa aprenda con el tiempo?**

- Correr los mismos evals pre-deploy cada release.
- Cada incidente produce al menos un nuevo eval case y un fix permanente. **Correcto**
- Aumentar la temperatura del modelo tras cada incidente.
- Reemplazar al equipo de IR después de un incidente SEV-1.

**Explicación:** Un postmortem sin follow-ups accionables es un documento olvidado. El criterio operativo de un programa de safety maduro: **cada incidente actualiza el regression suite**. Si el mismo bug aparece dos veces, el postmortem anterior fue inefectivo. Métricas de madurez: **MTTD** (detect), **MTTC** (contain), **MTTR** (recover), **repeat incident rate**, **% de incidentes con regression test**. Marcos como **EU AI Act Art. 72** y **NIST AI RMF (Manage function)** exigen documentar explícitamente este feedback loop como parte del post-market monitoring plan.
