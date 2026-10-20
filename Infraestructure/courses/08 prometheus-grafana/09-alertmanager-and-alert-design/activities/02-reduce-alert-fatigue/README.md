# obs-09-02 — Reducir alert fatigue (independent)

## 1. Identificacion
- **ID:** `obs-09-02-reduce-alert-fatigue`
- **Tecnologia:** prometheus-grafana
- **Modulo:** 09-alertmanager-and-alert-design
- **Dificultad:** intermediate
- **Duracion estimada:** 90 min
- **Tipo:** independent

## 2. Contexto
Heredas un `alerts.yaml` con **15 alertas** del equipo anterior. El on-call lleva meses quejandose: pages de madrugada por CPU alta en una maquina de staging, 7 alertas disparando a la vez cada vez que un nodo cae, alertas sin runbook, alertas que nadie recuerda haber visto resolver. Tu tarea: entregar un `alerts.yaml` con **exactamente 5 alertas** disenadas sobre **sintomas (SLO/user-impact)**, no causas, y un `WHY.md` que justifique por que cada una merece paginar y por que las otras 10 se eliminaron.

No se te da la solucion. Debes decidir que tirar, que fusionar y que reescribir.

## 3. Objetivos
- Diagnosticar un set de alertas ruidosas y clasificarlas (sintoma vs causa, actionable vs no).
- Rediseniar a 5 alertas SLO/sintoma con `for`, `severity`, `team`, `summary`, `description`, `runbook_url`.
- Documentar en `WHY.md` la razon de cada decision (keep, drop, merge, rewrite).
- Mantener `promtool check rules` en verde.

## 4. Prerrequisitos
- `theory/lesson.md` secciones 10 y 11 (sintomas vs causas, antidotos a fatigue).
- Docker o `promtool` nativo.

## 5. Instrucciones

### Paso 1 — Copia el starter y leelo
```bash
cp -r starter /tmp/obs-09-02
cd /tmp/obs-09-02
cat noisy-alerts.yaml
```

Lee las 15 alertas. Clasifica cada una mentalmente:
- Es **sintoma** (usuario lo nota) o **causa** (metrica interna)?
- Si disparara ahora, un humano **sabria que hacer** y **necesitaria hacerlo**?
- Hay otra alerta que ya cubre el mismo problema desde el angulo correcto?

### Paso 2 — Decide y escribe `alerts.yaml`
Crea `/tmp/obs-09-02/alerts.yaml` con **5 alertas**. Guia (no literal — tu decides nombres y expresiones):

1. **Disponibilidad del endpoint publico** (sintoma SLO: availability < 99.9% en ventana corta).
2. **Latencia p95 user-facing** (sintoma SLO: p95 > target).
3. **Error rate 5xx user-facing** (sintoma SLO).
4. **Burn-rate rapido del error budget** (opcional pero recomendado — predictor de incidente serio en < 1h).
5. **Database/dependency critical down** (causa que **si** es sintoma: si la DB cae, todo cae; justifica paginar aunque no sea user-facing stricto sensu).

Cada alerta debe tener: `for`, `severity`, `team`, `summary`, `description`, `runbook_url`.

### Paso 3 — Escribe `WHY.md`
Un fichero markdown con dos secciones:
- **Mantenidas (5)**: para cada alerta en tu `alerts.yaml`, explica en 1–3 lineas por que es un sintoma accionable.
- **Eliminadas (10)**: para cada alerta de las 15 originales que no sobrevive, explica en 1 linea el motivo (no actionable, causa sin predictor, duplicada por otra, umbral arbitrario, etc.).

### Paso 4 — Verifica
```bash
bash tests/validate.sh /tmp/obs-09-02
```

## 6. Resultado esperado
- `alerts.yaml` con **exactamente 5** alertas y `promtool check rules` OK.
- `WHY.md` con secciones "Mantenidas" y "Eliminadas" cubriendo 15 motivos (5 + 10).
- Ninguna de las 5 debe ser un umbral de recurso puro ("CPU > 80%") sin impacto demostrable.

## 7. Criterios de aceptacion
- Funcional: 5 alertas, campos obligatorios, promtool OK.
- Diseno: las 5 alertas son de sintoma o justifican por que una causa es equivalente a sintoma.
- Documentacion: `WHY.md` cubre las 15 originales.

## 8. Validacion
```bash
bash tests/validate.sh /tmp/obs-09-02
```

El validador comprueba:
- `alerts.yaml` existe y define **exactamente 5** reglas `alert:`.
- Cada alerta tiene `for`, `severity`, `team`, `summary`, `description`, `runbook_url`.
- `WHY.md` existe, menciona "Mantenidas" y "Eliminadas" y tiene al menos 15 bullets.
- `promtool check rules` (si disponible) devuelve `SUCCESS`.

Degradacion graceful: sin `promtool` ni docker, el check se marca `SKIP`.

## 9. Preguntas de reflexion
- Cual de las originales fue mas dura de **tirar**? Por que?
- Si tu equipo rechaza eliminar la alerta de "disk > 80%", que compromiso proponers? (Pista: `for`, severity, burn-rate del disco).
- Como demostrarias en 1 mes que la reduccion funciono? (Metricas sobre `alertmanager_notifications_total`).

## 10. Extensiones
- Agrega tests `promtool test rules` para 2 de tus 5 alertas.
- Disenia un `alertmanager.yml` con inhibition que acompanie este set.

## 11. Limpieza
```bash
rm -rf /tmp/obs-09-02
```
