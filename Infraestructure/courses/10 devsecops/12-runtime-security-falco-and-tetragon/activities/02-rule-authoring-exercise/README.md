# Actividad 02 — Escribir una regla Falco custom

## 1. Identificación

- **ID:** `sec-12-02-rule-authoring-exercise`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-12-runtime-security-falco-and-tetragon`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** independent (no depende de la actividad 01)

> **100 % offline.** No requiere cluster ni `kind` ni Falco instalado.

## 2. Caso de dominio

Tu equipo opera una plataforma donde **ningún** workload de aplicación debería escribir ficheros bajo `/var/log` con permisos world-writable (`chmod 777` o equivalente). Dos razones:

- Esos ficheros se consumen por un agente de logs (Fluentbit) corriendo como usuario dedicado; permisos abiertos permitirían tampering.
- Un atacante con RCE podría usar `/var/log/<x>` como dropper (log rotation + ejecución diferida).

**Tu tarea:** escribir una regla Falco que detecte este patrón, con su racional de FP/FN, y decidir si se promueve a enforcement con Tetragon.

## 3. Objetivos

- Producir `/tmp/sec-12-rule/custom-rules.yaml` con **al menos una** regla.
- Producir `/tmp/sec-12-rule/RULES.md` con el análisis en 4 secciones.
- Pasar el validador estructural.

## 4. Prerrequisitos

- Lección `theory/lesson.md` (§3, §4, §5, §7).
- Ejemplo `examples/02-write-falco-rule/` revisado.
- Editor de texto.
- Opcional: `python3` para validar YAML.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-12-rule
cd /tmp/sec-12-rule
```

Copia la plantilla:

```bash
REPO=/ruta/al/repo
cp "$REPO/courses/devsecops/12-runtime-security-falco-and-tetragon/activities/02-rule-authoring-exercise/starter/TEMPLATE.md" \
   /tmp/sec-12-rule/RULES.md
cp "$REPO/courses/devsecops/12-runtime-security-falco-and-tetragon/activities/02-rule-authoring-exercise/starter/custom-rules.template.yaml" \
   /tmp/sec-12-rule/custom-rules.yaml
```

### 5.2 Escribir la regla en `custom-rules.yaml`

Requisitos **estructurales** (los que valida el script):

- YAML válido parseable.
- Al menos **una entrada** con tipo `rule`.
- Cada `rule` tiene las claves: `rule`, `desc`, `condition`, `output`, `priority`.
- `priority` ∈ `{EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG}`.
- Al menos una condición mencionando `/var/log` **y** permisos world-writable (`777` o `S_IWOTH`-like).

Pista semántica (no la copies tal cual):

- Un `chmod 0777` sobre un archivo se traduce en el syscall `chmod` o `fchmodat` con el mode en `evt.arg.mode`.
- Un write en `/var/log` suele venir del event `open` con `fd.directory startswith "/var/log"`.
- Puedes modelar la regla como "chmod permisivo bajo /var/log" o como "escritura seguida de chmod permisivo" (más preciso, más complejo).

### 5.3 Escribir `RULES.md`

Cuatro secciones. Los títulos deben aparecer tal cual (el validador los busca):

```markdown
# RULES — chmod permisivo bajo /var/log

## Seccion A — Regla propuesta

(Pega aqui la regla YAML tal cual aparece en custom-rules.yaml,
en un bloque de codigo. Explica debajo cada decision:
condition, output, priority, tags.)

## Seccion B — Falsos positivos

(Al menos 2, numerados. Para cada uno: escenario legitimo + como lo suprimes
— exceptions nombradas o 'and not' extra en la condition.)

1. ...
2. ...

## Seccion C — Falsos negativos

(Al menos 2, numerados. Para cada uno: variante que evade la regla + regla
hermana o condicion extra que lo cubre.)

1. ...
2. ...

## Seccion D — Decision: detect vs enforce

- Recomendacion: detect / enforce / depende.
- Si enforce: boceto de TracingPolicy de Tetragon y riesgo asumido.
- Si detect: output elegido (stdout / Falcosidekick / SIEM) y por que.
```

### 5.4 Validar

```bash
REPO=/ruta/al/repo
bash "$REPO/courses/devsecops/12-runtime-security-falco-and-tetragon/activities/02-rule-authoring-exercise/tests/validate.sh" /tmp/sec-12-rule
```

### 5.5 Autoevaluación

Compara con `solution/REFERENCE.md` y `solution/custom-rules.yaml`.

## 6. Resultado esperado

- `/tmp/sec-12-rule/custom-rules.yaml` con YAML válido y al menos una `rule` completa.
- `/tmp/sec-12-rule/RULES.md` con las 4 secciones.
- Validador estructural en verde.

## 7. Criterios de aceptación

- **Funcional**: la regla cubre `chmod` permisivo bajo `/var/log` sin requerir que el proceso sea `chmod` literal (puede ser `install`, `cp -p`, `tar -xp`, etc. — tu regla debe pensarlo).
- **Analítico**: los FP/FN son concretos, no genéricos.
- **Operacional**: la decisión detect/enforce está defendida.

## 8. Preguntas de reflexión

1. ¿Por qué `priority: NOTICE` sería un error aquí y `WARNING` o `CRITICAL` sería mejor?
2. ¿Cómo cambiaría tu regla si tu organización corre contenedores donde `/var/log` **es** mount compartido entre workloads y agentes?
3. Si decides enforce con Tetragon, ¿qué `kprobe` usarías para capturar el `chmod` y por qué no un filtro basado en el nombre del proceso?
4. ¿Qué tag MITRE ATT&CK le pondrías y por qué?
5. Si esta regla disparara 50 veces al día en producción sin que ninguna sea maliciosa, ¿qué habrías hecho mal al escribirla?

## 9. Limpieza

```bash
rm -rf /tmp/sec-12-rule
```
