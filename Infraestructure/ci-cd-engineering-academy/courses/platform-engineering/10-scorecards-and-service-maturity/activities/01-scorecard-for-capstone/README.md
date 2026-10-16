# Actividad 01 — Diseñar y evaluar un scorecard para el capstone

## 1. Identificación

- **ID:** `plat-10-01-scorecard-for-capstone`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-10-scorecards-and-service-maturity`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (sin dependencia de la actividad 02)

## 2. Contexto

Tu capstone tiene (o tendrá) varios servicios. La pregunta que resuelve esta actividad es: *"¿qué 5–8 chequeos quiero que todos mis servicios cumplan y en qué nivel de madurez caen hoy?"*. El entregable es un `scorecard.yaml` propio evaluado contra un **catálogo sintético** de 5 servicios ya preparado en el starter.

**No necesitas Backstage, ni Node, ni levantar infra.** El evaluador es un script Python 3 estándar que lee JSON del catálogo y aplica tu YAML. Si tienes Backstage y quieres trasladar esto, el modelo mental es idéntico (ver `examples/01-techinsights-fact-and-check/`).

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir un `scorecard.yaml` con **5 a 8 chequeos**, cada uno justificado.
- Repartirlos entre **bronze, silver y gold** sin inventar un peso ponderado continuo.
- Ejecutar `python3 scripts/evaluate.py` y leer el reporte Markdown que produce.
- Argumentar qué **cortes** de adopción publicarías y cuáles **no**.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/`.
- Herramientas: `python3` (3.8+) con `pyyaml` disponible (`python3 -c "import yaml"` debe funcionar). `bash`, un editor Markdown y YAML. Nada más.

**Costos**: ninguno. Si `python3` o `pyyaml` no están disponibles, el validador salta en modo *skip* con un mensaje claro y la actividad se puede completar leyendo el starter.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-10-scorecard
cp -R starter/* /tmp/plat-10-scorecard/
cd /tmp/plat-10-scorecard
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

El directorio queda así:

```
/tmp/plat-10-scorecard/
├── catalog/                  # 5 servicios sintéticos en JSON (NO editar)
├── scripts/
│   └── evaluate.py           # evaluador local
└── scorecard.yaml.template   # plantilla para que la copies y edites
```

### 5.2 Escribe `scorecard.yaml`

Copia la plantilla:

```bash
cp scorecard.yaml.template scorecard.yaml
```

Edita `scorecard.yaml` para dejar **entre 5 y 8 chequeos**. La plantilla trae los 8 canónicos ya listos; puedes:

- Quitar los que no quieras.
- Añadir uno propio relevante a tu capstone (ej. `has-dashboard` si tu capstone requiere observabilidad obligatoria).
- Mover un chequeo entre niveles si lo defiendes.

Reglas que el evaluador exige:

- El archivo tiene **`levels: [bronze, silver, gold]`** (puedes añadir niveles intermedios, pero bronze/silver/gold deben estar).
- Entre **5 y 8** chequeos.
- Cada chequeo tiene: `id`, `description`, `weight` (uno de los niveles), `field`, `operator`. Opcional `value` según el operador.
- Operadores soportados: `is_set`, `equals`, `less_than`, `greater_than`, `in`.

### 5.3 Ejecuta el evaluador

```bash
python3 scripts/evaluate.py --scorecard scorecard.yaml --catalog catalog/ --out .
```

Esto produce dos archivos en el directorio actual:

- **`results.json`** — resultado por servicio (nivel + chequeos fallados).
- **`REPORT.md`** — reporte legible con tabla por servicio y adopción agregada.

### 5.4 Escribe `NOTES.md`

Un archivo `NOTES.md` en el mismo directorio con **tres secciones**:

#### Sección A — Decisiones de diseño

- Qué 5–8 chequeos elegiste y por qué.
- Qué chequeo **descartaste explícitamente** (y por qué induciría *gaming* o no mide resultado).
- Cómo repartiste los chequeos entre bronze/silver/gold.

#### Sección B — Lectura del reporte

- Qué porcentaje de los 5 servicios está en cada nivel.
- Qué servicio es el que **más cerca** está de subir de nivel (gap mínimo).
- Qué servicio es el que requiere **más inversión** (gap máximo).

#### Sección C — Adopción y antipatrones

- Dos cortes de adopción que publicarías (dominio, tier, antigüedad…) y por qué.
- Dos cortes que **no** publicarías y por qué.
- Dos antipatrones (de los que lista `theory/lesson.md` §8) que tu scorecard evita, nombrando cuál.

### 5.5 Entregable

Al terminar, el directorio `/tmp/plat-10-scorecard/` debe contener:

```
/tmp/plat-10-scorecard/
├── scorecard.yaml
├── results.json
├── REPORT.md
└── NOTES.md
```

## 6. Resultado esperado

- `scorecard.yaml` válido con 5–8 chequeos.
- `python3 scripts/evaluate.py` corre y produce `results.json` + `REPORT.md`.
- `NOTES.md` tiene las tres secciones (A, B, C) y menciona explícitamente al menos un antipatrón nombrado.
- `bash tests/validate.sh /tmp/plat-10-scorecard` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa; `evaluate.py` corre sin excepción.
- **Calidad**: cada chequeo tiene su justificación en `NOTES.md`; ningún chequeo es "actividad disfrazada de resultado".
- **Reproducibilidad**: cualquiera que corra `evaluate.py` sobre tu `scorecard.yaml` + el catálogo obtiene el mismo `results.json`.
- **Mantenibilidad**: ≤ 8 chequeos; sin pesos continuos opacos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-10-scorecard
```

El validador comprueba **estructura** y que el evaluador corra. **No** evalúa si tu reparto es "correcto" (hay varios razonables). Compara tu `scorecard.yaml` y `NOTES.md` con `solution/REFERENCE.md` para autoevaluarte.

Si `python3` o `pyyaml` no están disponibles, el validador reporta `SKIP` para la parte de ejecución y sigue validando la estructura textual. Puedes completar la actividad igualmente.

## 9. Preguntas de reflexión

1. ¿Por qué 5–8 chequeos y no 20? Da dos argumentos operativos, no estéticos.
2. Si un servicio pasa 7 de 8 chequeos de gold pero le falla `no-critical-cves`, ¿está "casi en gold"? ¿Qué daño hace tratarlo así?
3. ¿Qué chequeo de los 8 canónicos sacarías primero si vinieras de una organización con fuerte cultura de *gaming*?
4. ¿Qué información se **pierde** si publicas solo el porcentaje agregado por nivel y no publicas nada por equipo?
5. Si un equipo mantiene 1 servicio en gold y 4 en bronze, ¿su situación es mejor o peor que un equipo con 5 servicios en silver? Defiende la respuesta.

## 10. Extensiones

- Añade un chequeo propio (`has-dashboard`, `has-chaos-exercise-run`, etc.) con un fact ficticio en los JSON del catálogo (puedes editarlos — son sintéticos).
- Añade un nivel intermedio (ej. `silver+`) y argumenta por qué no es un escalón que invita a *gaming*.
- Reescribe el reporte agrupando por **dominio** (los 5 servicios del starter tienen el campo `domain`).

## 11. Limpieza

```bash
rm -rf /tmp/plat-10-scorecard
```

No hay procesos ni contenedores que detener.
