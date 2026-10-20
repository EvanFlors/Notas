# Actividad 01 — Construir un dashboard DORA desde eventos CI/CD

## 1. Identificación

- **ID:** `plat-11-01-build-dora-dashboard`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-11-metrics-dora-space-and-platform-as-product`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

El platform team de "Acme" necesita presentar al CTO el primer dashboard DORA. Hoy no hay nada — ni Four Keys, ni Backstage DORA plugin, ni dashboard de Grafana. Antes de comprar o integrar, el PM de la plataforma quiere **demostrar** que las 4 métricas se pueden computar desde un simple flujo de eventos y que la interpretación es tan importante como el número.

Esta actividad simula eso: un script genera **eventos sintéticos** (commits mergeados, deploys, incidents) para **dos servicios** con perfiles muy distintos; otro script computa DORA; tú escribes el documento que presenta los resultados al CTO.

## 3. Objetivos

Al terminar deberías poder:

- Generar un `events.json` sintético y determinista con 2 servicios distintos.
- Computar las 4 DORA metrics desde ese JSON con un script Python puro.
- Clasificar cada servicio en un **bucket** DORA y justificar la clasificación.
- Escribir un documento que resista la crítica "más deploys ≠ mejor plataforma".

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§2–§6).
- Haber ejecutado los `../../examples/01-dora-from-ci-cd-events/`.
- Tener `python3` (3.9+) instalado. Nada más (stdlib pura).

**Costos**: cero.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-11-dora
cd /tmp/plat-11-dora
```

Si usas otro directorio, pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Generar los eventos sintéticos

Copia los scripts del starter y ejecútalos:

```bash
cp <ruta-repo>/courses/platform-engineering/11-metrics-dora-space-and-platform-as-product/activities/01-build-dora-dashboard/starter/*.py .
python3 generate_events.py --out events.json
```

El generador crea datos deterministas (seed fija) para **dos servicios**:

- `checkout-api` — perfil *high performer*: ~24 deploys en 28 días, lead time ~4h, 1–3 incidents cortos.
- `legacy-billing` — perfil *low performer*: ~3 deploys en 28 días, lead time ~5 días, incidents largos.

### 5.3 Computar DORA por servicio

```bash
python3 compute_dora.py events.json --service checkout-api  > dora_checkout.txt
python3 compute_dora.py events.json --service legacy-billing > dora_billing.txt
```

Revisa los dos outputs. Observa cómo los dos servicios caen en **buckets distintos** aunque viven en el mismo repo-ish y en la misma plataforma.

### 5.4 Escribir `DORA.md`

Crea `/tmp/plat-11-dora/DORA.md` con **cuatro secciones**:

#### Sección A — Resumen ejecutivo (3–5 líneas)

Una sola frase por cada servicio con bucket + número headline + una idea clave.

#### Sección B — Tabla de métricas

Tabla con **columnas: Métrica, checkout-api, legacy-billing, Bucket checkout, Bucket billing**. Cuatro filas (DF, LTC, CFR, FDRT).

#### Sección C — Interpretación

Para cada servicio, 2–3 bullets que respondan:

- ¿Qué métrica es la que *fija* el bucket (el peor de las 4)?
- ¿Qué palanca de ingeniería / plataforma movería esa métrica (trunk-based, feature flags, canary, blue/green, mejor test suite, mejor observabilidad)?
- ¿Qué métrica NO deberías celebrar sin mirar las otras? (Pista: Goodhart.)

#### Sección D — 3 recomendaciones accionables

Tres recomendaciones concretas (no "mejorar la cultura") priorizadas por impacto esperado. Cada una debe citar **la métrica DORA que debería mover** y en cuánto.

### 5.5 Entregable

```
/tmp/plat-11-dora/
├── events.json       # generado por el starter
├── dora_checkout.txt # output del compute_dora.py
├── dora_billing.txt  # output del compute_dora.py
└── DORA.md           # tu análisis
```

## 6. Resultado esperado

- `events.json` existe y contiene eventos de **ambos** servicios.
- `dora_checkout.txt` y `dora_billing.txt` existen y mencionan los 4 nombres de métricas.
- `DORA.md` tiene las 4 secciones (A/B/C/D), nombra ambos servicios, menciona los 4 nombres de métricas y los 4 buckets DORA (Elite/High/Medium/Low al menos 2 de los 4 citados), y referencia **Goodhart** o *vanity metric* en algún punto.
- `bash tests/validate.sh /tmp/plat-11-dora` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: el validador estructural pasa.
- **Calidad**: cada recomendación en la Sección D cita una métrica concreta a mover.
- **Honestidad intelectual**: no celebras `legacy-billing` por tener CFR bajo si en realidad despliega una vez al mes (típico *trap*).
- **Reproducibilidad**: los eventos son deterministas (seed fija); otro estudiante que corra el starter obtiene los mismos números.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-11-dora
```

El validador verifica **estructura** (archivos, secciones, menciones clave). La corrección conceptual se compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué DORA mide **mediana** de lead time y de recovery time, en lugar de media?
2. Un servicio con CFR del 0 % y DF de 1 deploy/mes, ¿qué te dice realmente? ¿Es "excelente"?
3. ¿Qué cambia si tu organización define "deploy" como "release" (feature flipped off) en vez de "código llegó a prod"?
4. Si tu PagerDuty no tiene campo `caused_by_deploy_id`, ¿cómo aproximarías CFR sin falsear la métrica?
5. El CTO ve el dashboard y pregunta: "¿por qué no es Elite todo?". ¿Cómo respondes sin volverte defensivo ni comprometerte a serlo en Q+1?

## 10. Extensiones

- Añade un **tercer servicio** al generador (`notifications-worker`) con perfil "medium" y re-ejecuta.
- Genera un diff visual: imprime una tabla ASCII comparando los tres servicios en una sola corrida.
- Añade *failed deploys* explícitos (no todos los deploys son success) y asegúrate de que **no** se cuentan en CFR (CFR es sobre deploys exitosos que luego causan incident).

## 11. Limpieza

```bash
rm -rf /tmp/plat-11-dora
```

No hay procesos ni contenedores que detener.
