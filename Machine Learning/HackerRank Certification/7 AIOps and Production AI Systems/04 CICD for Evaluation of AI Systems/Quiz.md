# Quiz: CI/CD para evaluación de sistemas de AI

Tu equipo está construyendo un pipeline CI/CD para un modelo de recomendación. El modelo tarda 6 horas en entrenar y hay 5 data scientists haciendo cambios de código diariamente. Necesitas balancear iteración rápida con testing exhaustivo mientras controlas los costos de recursos.

---

**1. Los data scientists hacen push de cambios de código 10 veces al día. Entrenar el modelo completo tarda 6 horas y cuesta USD 50. ¿Cómo deberías configurar los triggers del pipeline de training?**

- [ ] Disparar entrenamiento completo en cada commit de código para feedback inmediato.
- [ ] Nunca automatizar el entrenamiento; disparar siempre manualmente.
- [x] **Programar entrenamiento nocturno y disparar solo ante cambios específicos (data, arquitectura, config del modelo).**
- [ ] Entrenar solo cuando las métricas de evaluación del modelo degradan.

**Explicación:** El patrón canónico es **separar el code pipeline del training pipeline**. Entrenar en cada commit desperdicia USD 500/día y 60 horas de GPU para cambios que normalmente no requieren retrain (un rename de variable, un fix de typo, una mejora del logging). Las políticas correctas de trigger son: **schedule nocturno**, cambio de **data** (data pipeline sensor), cambio de **arquitectura o hiperparámetros**, o **degradación de métricas detectada** en monitoring. Para los cambios de código normales, los tests corren contra el modelo **actual** registrado, que es lo que valida que el serving code sigue funcionando. "Nunca automatizar" es el otro extremo y crea cuellos de botella operativos.

---

**2. Tu suite de tests de regresión incluye 50 casos críticos. Un nuevo modelo pasa 48 de 50 pero tiene 2% más de accuracy global que el modelo actual. ¿Qué deberías hacer?**

- [ ] Deployar el nuevo modelo porque mejoró la accuracy global.
- [x] **Investigar los 2 casos fallidos antes de tomar una decisión de deployment.**
- [ ] Bajar el umbral de aprobación de la suite de regresión a 48 de 50.
- [ ] Saltar los tests de regresión ya que las métricas globales mejoraron.

**Explicación:** Los **behavioral regression tests** encodean reglas de negocio que **nunca deberían romperse** (compliance, casos críticos, seguridad). Una mejora de 2% en accuracy global es *promedio* y puede estar escondiendo una regresión concentrada en los casos que más importan. Los 2 fallos pueden ser: un cambio de política de refund mal manejado, una regresión en el idioma español, un prompt injection que ahora se cuela, o un cambio de formato de salida que rompe downstream. **Nunca** se baja el umbral para "hacer pasar" al modelo (eso convierte el gate en teatro) ni se saltan los tests ("el promedio subió" no justifica romper un contrato). Investigar los fallos → decidir con información completa. Si los 2 casos son obsoletos, se actualiza el golden set documentándolo; si son reales, el modelo no promueve.

---

**3. El pipeline de training ocasionalmente falla por data corrupta. Cada fallo desperdicia 6 horas y USD 50. ¿Dónde deberías agregar validación de datos?**

- [x] **Al inicio del pipeline de training, antes de las operaciones costosas.**
- [ ] Después de que el entrenamiento termina, validar el modelo entrenado.
- [ ] Solo en el serving de producción para detectar problemas en runtime.
- [ ] La validación de datos no es necesaria si las fuentes son confiables.

**Explicación:** El principio es **"fail fast"**: detectar problemas lo antes posible, antes de gastar recursos caros. Validar al final del training no evita el desperdicio de 6h/USD 50. Validar solo en serving es tarde: ya tienes un modelo en producción que podría estar entrenado con basura. "Las fuentes son confiables" es una suposición que falla: ETLs cambian, schemas se desactualizan, upstream mete `null` en vez de `0`, un deploy aguas arriba rompe la convención. Las dimensiones a validar primero: **schema** (Pandera, Great Expectations), **completeness** (tasa de nulos), **freshness** (timestamp del dato más reciente dentro de SLA), **distribución** (PSI o KS contra referencia), **uniqueness** (keys sin duplicados) y **consistency** (invariantes entre columnas). El costo de la validación es segundos; el costo de no validar es horas y dinero.

---

**4. Tu equipo nunca ha probado el procedimiento de rollback para deployments de modelos. Durante un incidente necesitas hacer rollback pero el procedimiento falla. ¿Qué práctica lo habría evitado?**

- [ ] Testing pre-deployment más exhaustivo.
- [ ] Canary deployments con rollback automático.
- [ ] Deployments más lentos y graduales.
- [x] **Drills regulares de rollback en entornos de staging.**

**Explicación:** El **rollback no testeado = rollback que falla cuando más lo necesitas**. Las razones por las que un rollback "obvio" rompe en producción son muchas: migraciones de DB no reversibles, cambios de schema de embeddings, dependencias eliminadas en el nuevo deploy, scripts que asumen estado que ya no existe, documentación desactualizada, personas con permisos distintas entre el deploy y la emergencia, DNS caches, etc. Un canary con auto-rollback **ayuda durante el rollout** pero no cubre el escenario de este caso: ya pasaron horas desde el deploy y aparece un problema. La **única** forma de garantizar que el rollback funcione es **ejercitarlo regularmente** en staging: drills mensuales, chaos engineering ("Chaos Monkey rolleando random"), game days. Los otros ítems son buenos pero no resuelven el síntoma; "testing más exhaustivo" previene *algunos* bugs pero no los invisibles; "deployments más lentos" prolonga el periodo de riesgo sin resolver el rollback.

---

**5. Los modelos pasan todos los tests en desarrollo pero fallan en producción por computación diferente de features. ¿Qué principio se violó?**

- [ ] Cobertura insuficiente de tests unitarios.
- [ ] Load testing inadecuado en staging.
- [x] **Environment parity — la computación de features difiere entre entornos.**
- [ ] Faltan tests de integración.

**Explicación:** Esto es el clásico **training-serving skew**: el modelo se entrenó con features computadas de una forma (por ejemplo, con Pandas en el notebook: `df.rolling(7).mean()`) y en producción se computan de otra (streaming con Flink, SQL en Snowflake, lógica reimplementada en Go). Aunque el input "lógico" es el mismo, los valores numéricos divergen: diferentes manejos de nulos, diferentes definiciones de "últimos 7 días", diferente ordenamiento, diferente timezone. El modelo recibe features **distintas** a las que vio en training → predicciones degradadas. Más unit tests no lo detectan si cada entorno tiene su propia implementación; más load testing mide latencia, no corrección semántica; más integration tests ayudan **si** incluyen un check de paridad. La solución es **environment parity**: usar la **misma** biblioteca/código de feature computation en training y serving (feature store compartido: Feast, Tecton, Databricks Feature Store), o si eso no es posible, un **integration test** que corra la misma data por los dos pipelines y haga assert de que las salidas son idénticas byte a byte. Esto se complementa con **data parity** (subsets representativos en dev), **infra parity** (mismo tipo de GPU en staging) y **config parity** (externalizada, no hardcodeada).
