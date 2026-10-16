# plat-02 — Lección: golden paths, paved roads y Developer Experience

> 10 secciones. 100 % conceptual. Prerrequisito: `plat-01` (Team Topologies, cognitive load).

---

## 1. El problema: cada microservicio una "aventura"

Sin plataforma, cada equipo que arranca un servicio nuevo repite decisiones triviales:

- ¿qué framework HTTP?
- ¿qué cliente de logging? ¿JSON? ¿plano?
- ¿qué pipeline de CI? ¿GHA? ¿CircleCI?
- ¿cómo despliego? ¿Helm? ¿kustomize? ¿raw manifests?
- ¿cómo autentica entre servicios?
- ¿qué base image?
- ¿métricas Prometheus? ¿OTel? ¿ambos?

Cada equipo responde distinto. El resultado:

- **Variabilidad** altísima entre servicios. Nada se parece a nada.
- **Cognitive load extraneous** (ver `plat-01`): cada ingeniero carga con decisiones que no aportan a su dominio.
- La organización paga **N veces** por el mismo pipeline, el mismo logging, el mismo auth.

Un *golden path* ataca exactamente esto: convierte N decisiones triviales en **una decisión colectiva** tomada por el platform team y expuesta como un producto.

---

## 2. Definición operativa

Un **golden path** es:

1. Un **camino preferido** para una tarea recurrente (crear microservicio, publicar librería, provisionar DB, montar un endpoint evento-driven).
2. **Soportado** activamente por el platform team: incidentes, upgrades, roadmap.
3. Con la **mejor DX** disponible: menos pasos, menos errores, menos fricción.
4. **Documentado** como producto: README, ADRs, changelog, versionado.
5. **Opt-in**: puedes salirte. Si te sales, pierdes soporte, pero no te castigan.

> "Golden path" no es *un repositorio template*. Es el **conjunto**: template + CI + runtime + observabilidad + runbooks + ownership + versionado + feedback loop.

---

## 3. "Paved road" (Netflix): mismo concepto, mayor compromiso

Netflix popularizó el término **paved road**:

- Mismo camino preferido, pero el platform team **opera parte del stack en nombre del usuario** (no solo lo documenta: también lo hospeda, lo parchea, lo rola).
- Si vas por fuera del paved road, estás **"off road"**: puedes hacerlo, pero asumes tú el on-call, los upgrades, las migraciones.
- La asimetría entre on-road y off-road es **deliberada**: hace que la mayoría elija on-road sin coacción.

Diferencia práctica con "golden path":

- Golden path pone el foco en la **experiencia** (documentación, templates, UX).
- Paved road pone el foco en la **operación** (quién lo rola, quién lo parchea, quién recibe la page).

En la mayoría de las organizaciones estos términos se usan como sinónimos. Internamente conviene aclararlos para evitar ambigüedad.

---

## 4. Golden path vs mandato

| Dimensión | Golden path | Mandato |
|-----------|-------------|---------|
| Mecánica | **Opt-in**: por default, mejor experiencia | **Forzado**: policy-as-code, admission controller, CI gate |
| Enforcement | Social + técnico (fricción diferencial) | Técnico (bloquea) |
| Riesgo si falla | Equipos innovan por fuera | Equipos se saltan la plataforma por "shadow IT" o se bloquean |
| Buen uso | Convergencia natural | **Después** de que el path está probado y adoptado |

**Regla operativa:** un mandato **sin golden path previo** es una receta para el resentimiento. Primero construye el camino, demuestra que es más fácil, mide adopción espontánea, **después** cierra la puerta a los demás.

---

## 5. Criterios para el **primer** golden path

No todos los paths valen la pena. Un primer path candidato debe cumplir, idealmente, **cuatro** criterios:

1. **Volumen**: el caso ocurre con frecuencia (ej. "nuevo microservicio" en una org con muchos equipos; **no** "pipeline para entrenar un modelo ML" si solo hay 1 equipo).
2. **Variabilidad baja**: 80 % de los casos se parecen. Si cada microservicio es un copo de nieve, no hay path que optimice ese caso general.
3. **Dolor compartido**: todos los equipos coinciden en que el setup actual es doloroso.
4. **Impacto medible**: tienes forma de medir el *antes* y el *después* (p. ej. TTP, # de tickets de onboarding).

Un quinto criterio recomendable:

5. **Bajo riesgo de regresión**: el primer path **no** debería ser el que corre el pago en producción. Elige algo donde el peor caso sea "equipo re-genera el repo", no "pérdida de datos".

Un primer path **mal elegido** destruye credibilidad y hace que el platform team pierda su "mandato social" para los siguientes.

---

## 6. DX como métrica: 6 métricas y sus trampas

| Métrica | Qué mide | Cómo se puede gamificar |
|---------|----------|-------------------------|
| **Time-to-first-commit** | Minutos desde "quiero un servicio" hasta primer commit productivo | Scaffolder genera commit "inicial" vacío; la métrica cae a cero sin que la DX mejore |
| **Time-to-production (TTP)** | Horas/días desde `git init` hasta prod | Equipos despliegan "hola mundo" en prod para marcar el checkbox |
| **Tasa de errores de onboarding** | % de intentos de scaffolding/registro que fallan en N horas | Se baja ocultando errores en logs internos; el usuario queda igual de frustrado |
| **Platform NPS** | Encuesta periódica (promotores − detractores) | Autoselección (solo responden los contentos); redacción de la pregunta |
| **Tickets evitados** | Tickets que *no* se abrieron porque el path cubre el caso | Imposible de medir directamente; se estima con intervención y es ruidoso |
| **Adopción** | % de servicios creados vía el path | Se infla contando repos de prueba o repos deprecados |

**Ley de Goodhart aplicada:** *cuando una métrica se vuelve objetivo deja de ser una buena métrica*. Por eso casi siempre se mide una **constelación** (p. ej. TTP + NPS + ticket backlog) y se añaden **cualitativos** (DX interviews).

Un platform team **sin métricas DX** opera a ciegas. Con **una sola** métrica DX, opera gamificado. Con **tres a cinco** balanceadas, puede dirigir el producto.

---

## 7. El "long tail": qué hacer con el 20 % que no entra

Un golden path razonablemente bien diseñado cubre el 60–80 % de los casos. El resto es el **long tail**:

- Servicios con requerimientos que el path no soporta (p. ej. compliance HIPAA, latencias < 1 ms, binario C++).
- Servicios legacy que preceden al path.
- Experimentos / spikes que no justifican la fricción del path.

Tres posturas razonables:

- **Opción B soportada**: el platform team ofrece un segundo camino menor (p. ej. "microservicio Rust" junto al "microservicio Python" principal). Más overhead para la plataforma, mejor cobertura.
- **Opción B no soportada**: el equipo puede salirse, pero asume on-call, upgrades y seguridad por su cuenta. Comunicación clara, no castigo.
- **Mandato selectivo**: en zonas de alto riesgo (p. ej. servicios que manejan PII), el camino **sí** es obligatorio y el long tail no se tolera.

El **error típico** es tratar el long tail como "ruido" y despreciarlo. Esos equipos suelen ser los que te enseñarán el siguiente golden path.

---

## 8. Evolución y deprecations

Un path **vive y muere**. Reglas mínimas:

- **Versiona** el path (SemVer o fecha). Un repo generado dice "generado con path v3.2.0".
- **Changelog** del path, con notas de migración.
- Para deprecar: ciclo **anuncio → warn (en el scaffolder) → remove**, con TTL explícito (ej. 6 meses).
- Herramienta `update-from-template` (o equivalente) para "re-pescar" mejoras desde el path hacia repos ya scaffoldeados sin re-generarlos a mano.
- Nunca deprecar **sin ofrecer camino de migración**: eso rompe la confianza y empuja equipos al long tail.

---

## 9. Feedback loops explícitos

Si el único feedback que recibe el platform team son los tickets, está midiendo **lo que ya falló**. Tres canales **adicionales** y complementarios:

- **Entrevistas DX** (cualitativo): 30–45 min, 4–6 preguntas abiertas, un developer a la vez, cadencia trimestral. No "¿te gusta la plataforma?" sino "cuéntame tu último scaffolding desde el click al primer deploy — ¿dónde dudaste?".
- **Survey** (cuantitativo con texto libre): Platform NPS + 3–5 preguntas Likert + un campo abierto. Cadencia semestral. Baja fricción.
- **Telemetría de uso** (observacional): templates ejecutados, errores en el scaffolder, tiempo entre pasos, abandono. Objetiva, pero ciega al "por qué".

**Los tres juntos** se corroboran: la telemetría dice *dónde* duele; la encuesta, *cuánto*; la entrevista, *por qué*.

---

## 10. Antipatterns de golden paths

- **Golden path "en papel"**: documentado pero no soportado. Degrada a wiki muerta.
- **Golden cage**: tan rígido que para cualquier variación hay que pedir permiso. Vuelve al platform team un cuello de botella.
- **Mandato prematuro**: forzar antes de medir adopción espontánea.
- **"Nuestro Backstage"** confundido con "nuestro golden path": herramienta ≠ camino.
- **Métrica única** (típico: solo TTP): optimiza una variable y degrada las demás silenciosamente.
- **Sin owner**: nadie en el platform team es responsable del path. Se degrada en meses.
- **Long tail despreciado**: los equipos "difíciles" se vuelven el próximo shadow IT.
- **Deprecations sin migración**: destruye la confianza acumulada.

> **Idea a repetir hasta que suene aburrido:** un buen golden path **elimina decisiones triviales** y libera energía para decisiones de dominio. Un mal golden path se vuelve un *parque jurásico* porque nadie puede cambiarlo sin romper mil cosas.
