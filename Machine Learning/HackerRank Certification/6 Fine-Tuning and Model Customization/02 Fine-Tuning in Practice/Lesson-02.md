# Preparación y Expansión del Dataset

## ¿Qué es?

La **preparación de dataset** es el conjunto de pasos que transforma datos crudos en un corpus listo para fine-tuning: limpieza, validación de calidad, análisis de diversidad, generación sintética para rellenar huecos y validación final previa al entrenamiento. En la práctica, esto consume **60-80% del tiempo** de un proyecto de fine-tuning serio y determina más del resultado que la elección del algoritmo.

Para el **chatbot de soporte al cliente** del submódulo partes con 2,000 interacciones extraídas del sistema de tickets. Algunas son excelentes; otras tienen duplicados, campos faltantes, formatos inconsistentes y categorías desbalanceadas. Tu trabajo es dejarlo listo para que el modelo aprenda patrones **generalizables**, no ruido.

### Las cinco dimensiones de calidad

| Dimensión | Qué significa | Impacto si falla |
|---|---|---|
| **Completeness** | Todos los campos requeridos están presentes y no vacíos | Ejemplos descartados o patrones incompletos |
| **Accuracy** | Las etiquetas/outputs son correctos | Modelo aprende comportamientos equivocados |
| **Consistency** | Formato uniforme (mismo casing, misma estructura) | Modelo aprende múltiples formas de la misma cosa |
| **Relevance** | Los ejemplos pertenecen a la tarea objetivo | Dilución de señal, pérdida de compute |
| **Diversity** | Cubre el rango completo de escenarios de producción | Modelo frágil ante edge cases |

## ¿Por qué importa?

Datos malos entrenan modelos malos. Es tan directo como eso. Un dataset con 80% de calidad produce un modelo que falla en 20% de los inputs reales, lo que a escala significa miles de clientes mal atendidos. Peor aún: en instruction tuning, los errores no son uniformes — los ejemplos defectuosos enseñan **comportamientos específicos equivocados** (ej. clasificar siempre como "Shipping" porque esa clase está sobrerrepresentada).

La preparación bien hecha paga tres dividendos:

1. **Menos compute desperdiciado:** detectas problemas antes de un training run de 3 horas.
2. **Mejor convergencia:** menos ruido = menos épocas necesarias.
3. **Mejor generalización:** diversidad y balance evitan overfitting a patrones espurios.

### Cuándo correr la validación

- **Tras la recolección inicial:** detectar problemas sistémicos pronto.
- **Tras cada paso de limpieza:** confirmar que las correcciones funcionaron.
- **Antes del training:** check final, no negociable.
- **En producción (data que llega nueva):** automatiza con alertas si la calidad cae.

## ¿Cómo funciona?

### Paso 1: Inspección estructural

Antes de limpiar, entiende qué tienes. Revisa estructura, tipos, longitudes y campos faltantes.

```python
import json
from collections import Counter

def examinar_dataset(ruta):
    with open(ruta, "r", encoding="utf-8") as f:
        data = json.load(f)

    print(f"Total de ejemplos: {len(data)}")
    sample = data[0]
    print("\nEstructura del primer ejemplo:")
    for k, v in sample.items():
        tipo = type(v).__name__
        largo = len(str(v)) if isinstance(v, str) else "N/A"
        print(f"  {k}: {tipo} (len={largo})")

    requeridos = ["instruction", "input", "output"]
    faltantes = {f: 0 for f in requeridos}
    for ex in data:
        for f in requeridos:
            if f not in ex or not ex[f]:
                faltantes[f] += 1
    print("\nCampos faltantes:", faltantes)
    return data

raw_data = examinar_dataset("data/soporte_raw.json")
```

### Paso 2: Eliminación de duplicados

Los duplicados desperdician compute y provocan overfitting silencioso. Elimínalos por hash de los campos clave (`instruction` + `input`).

```python
def eliminar_duplicados(dataset, key_fields=("instruction", "input")):
    seen = set()
    unicos = []
    dups = 0
    for ex in dataset:
        key = tuple(str(ex.get(f, "")) for f in key_fields)
        if key in seen:
            dups += 1
        else:
            seen.add(key)
            unicos.append(ex)
    print(f"Eliminados: {dups} ({dups/len(dataset)*100:.1f}%)")
    return unicos

clean = eliminar_duplicados(raw_data)
```

Para duplicados **semánticos** (texto distinto, mismo significado), usa embeddings y un umbral de similitud coseno:

```python
from sentence_transformers import SentenceTransformer, util
import torch

model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
textos = [ex["input"] for ex in clean]
emb = model.encode(textos, convert_to_tensor=True, show_progress_bar=True)

sim = util.cos_sim(emb, emb)
mask = torch.triu(torch.ones_like(sim), diagonal=1).bool()
dup_idx = (sim.masked_fill(~mask, 0) > 0.95).any(dim=0)
clean = [ex for i, ex in enumerate(clean) if not dup_idx[i]]
```

### Paso 3: Evaluación de calidad multidimensional

```python
def evaluar_calidad(dataset, validaciones=None):
    if validaciones is None:
        validaciones = {
            "completeness": lambda e: all(f in e and e[f] for f in ["instruction", "input", "output"]),
            "format":       lambda e: len(e.get("instruction", "")) >= 10,
            "relevance":    lambda e: len(e.get("input", "")) > 0,
        }

    issues = {k: [] for k in validaciones}
    for i, ex in enumerate(dataset):
        for dim, fn in validaciones.items():
            if not fn(ex):
                issues[dim].append(i)

    total = len(dataset)
    scores = {k: 1 - len(v) / total for k, v in issues.items()}
    overall = sum(scores.values()) / len(scores)
    return {"scores": scores, "overall": overall, "issues": issues, "total": total}

def es_soporte(ex):
    txt = ex.get("input", "").lower()
    kws = ["pedido", "envio", "devolucion", "reembolso", "producto", "cuenta", "pago", "orden"]
    return any(k in txt for k in kws)

custom = {
    "completeness": lambda e: all(f in e and e[f] for f in ["instruction", "input", "output"]),
    "format": lambda e: len(e.get("instruction", "")) >= 10,
    "relevance": es_soporte,
}

reporte = evaluar_calidad(clean, custom)
print(f"Calidad general: {reporte['overall']:.2%}")
for dim, s in reporte["scores"].items():
    print(f"  {dim}: {s:.2%}")

if reporte["overall"] < 0.90:
    print("\n⚠️ Calidad bajo 90%. Revisa y corrige antes de entrenar.")
```

### Paso 4: Análisis de diversidad y balance

Dataset homogéneo = modelo frágil. Si el 70% de tus tickets son "problemas de envío", tu chatbot fallará en facturación o soporte técnico.

```python
import numpy as np
from collections import Counter

def analizar_diversidad(dataset, extraer_cats=None):
    largos = [len(str(ex.get("input", ""))) for ex in dataset]
    long_stats = {
        "media": float(np.mean(largos)),
        "std": float(np.std(largos)),
        "min": int(np.min(largos)),
        "max": int(np.max(largos)),
        "cv": float(np.std(largos) / np.mean(largos)) if np.mean(largos) > 0 else 0,
    }

    balance = None
    balanced = True
    if extraer_cats:
        cats = []
        for ex in dataset:
            c = extraer_cats(ex)
            if c:
                cats.extend(c if isinstance(c, list) else [c])
        if cats:
            cnt = Counter(cats)
            total = sum(cnt.values())
            balance = {k: v / total for k, v in cnt.items()}
            balanced = all(0.05 <= r <= 0.60 for r in balance.values())

    tareas = []
    for ex in dataset:
        instr = ex.get("instruction", "").lower()
        if "clasifica" in instr:
            tareas.append("clasificacion")
        elif "genera" in instr or "respuesta" in instr:
            tareas.append("generacion")
        elif "extrae" in instr:
            tareas.append("extraccion")

    return {
        "longitud": long_stats,
        "balance": balance,
        "balanceado": balanced,
        "tareas": dict(Counter(tareas)),
    }

def extraer_cat_soporte(ex):
    if "clasifica" not in ex.get("instruction", "").lower():
        return None
    out = ex.get("output", "")
    cats = []
    for cat in ["Envío", "Facturación", "Producto", "Devolución", "Técnico"]:
        if cat in out:
            cats.append(cat)
    return cats or None

div = analizar_diversidad(clean, extraer_cat_soporte)
print("Balance:", div["balance"])
print("¿Balanceado?", div["balanceado"])
print("Tareas:", div["tareas"])
```

### Paso 5: Generación sintética

Si identificas categorías infrarepresentadas (ej. pocas devoluciones), generarás ejemplos adicionales. Dos estrategias:

**A) Template-based (rápido, barato, estructurado):**

```python
import random

def generar_desde_templates(templates, pools, n_por_template):
    sinteticos = []
    for tpl in templates:
        for _ in range(n_por_template):
            inp = tpl["input_template"]
            out = tpl["output_template"]
            for var, valores in pools.items():
                v = random.choice(valores)
                inp = inp.replace(f"{{{var}}}", str(v))
                out = out.replace(f"{{{var}}}", str(v))
            sinteticos.append({"instruction": tpl["instruction"], "input": inp, "output": out})
    return sinteticos

templates_devolucion = [{
    "instruction": "Clasifica este ticket por urgencia y categoría.",
    "input_template": "Quiero devolver {item} de la orden #{num}. {razon}",
    "output_template": "Urgencia: {urg}\nCategoría: Devolución",
}]

pools = {
    "item": ["una chaqueta", "los zapatos", "el electrónico", "los libros"],
    "num": [str(random.randint(10000, 99999)) for _ in range(50)],
    "razon": ["no me queda", "talla equivocada", "defectuoso", "cambié de opinión"],
    "urg": ["Baja", "Media", "Alta"],
}

sinteticos = generar_desde_templates(templates_devolucion, pools, 50)
print(f"Generados: {len(sinteticos)}")
```

**B) LLM-guided (más natural, costoso):**

```python
from openai import OpenAI
import json

client = OpenAI()

def generar_con_llm(seeds, n, descripcion):
    seed_txt = "\n\n".join(
        f"Instruction: {s['instruction']}\nInput: {s['input']}\nOutput: {s['output']}"
        for s in seeds[:5]
    )
    prompt = f"""Tarea: {descripcion}

Genera {n} ejemplos diversos siguiendo este formato (JSON array):

{seed_txt}

Requisitos:
- Diversos en estilo, longitud, complejidad.
- Mismo formato instruction/input/output.
- Cubrir distintos escenarios y edge cases.
- Responde SOLO un objeto JSON {{"examples": [...]}}
"""
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
        response_format={"type": "json_object"},
    )
    return json.loads(resp.choices[0].message.content).get("examples", [])
```

### Paso 6: Validación de datos sintéticos

**Nunca** integres sintéticos sin validar: duplicados contra el dataset real, longitud mínima, formato correcto.

```python
def validar_sinteticos(sinteticos, existentes, reglas=None):
    if reglas is None:
        reglas = {
            "campos": lambda e: all(f in e for f in ["instruction", "input", "output"]),
            "no_dup": lambda e: not any(
                e.get("instruction") == x.get("instruction") and e.get("input") == x.get("input")
                for x in existentes
            ),
            "longitud": lambda e: len(e.get("input", "")) >= 20,
        }
    ok, rechazados = [], []
    for ex in sinteticos:
        fallas = [n for n, fn in reglas.items() if not fn(ex)]
        (rechazados if fallas else ok).append((ex, fallas) if fallas else ex)
    return {"ok": ok, "rechazados": rechazados, "tasa": len(ok) / len(sinteticos) if sinteticos else 0}

v = validar_sinteticos(sinteticos, clean)
print(f"Tasa de validación: {v['tasa']:.2%}")
validados = v["ok"]
```

### Paso 7: Train/val split y mezcla

Mezcla real + sintético con ratio conservador (20-30% sintético). Nunca más del 40%.

```python
import random

def crear_dataset_mixto(real, sinteticos, ratio_sint=0.25, seed=42):
    random.seed(seed)
    total = len(real) / (1 - ratio_sint)
    n_sint = int(total * ratio_sint)
    mix = real.copy() + sinteticos[:min(n_sint, len(sinteticos))]
    random.shuffle(mix)
    return mix

def split_train_val(dataset, val_ratio=0.1, seed=42):
    random.seed(seed)
    data = dataset.copy()
    random.shuffle(data)
    n_val = int(len(data) * val_ratio)
    return data[n_val:], data[:n_val]

final = crear_dataset_mixto(clean, validados, 0.25)
train, val = split_train_val(final, val_ratio=0.1)
print(f"Train: {len(train)} | Val: {len(val)}")
```

### Paso 8: Validación completa pre-training

```python
def validar_para_training(dataset, min_size=2000, threshold=0.90):
    res = {}
    res["tamano"] = {"n": len(dataset), "ok": len(dataset) >= min_size}
    q = evaluar_calidad(dataset, custom)
    res["calidad"] = {"overall": q["overall"], "ok": q["overall"] >= threshold}
    d = analizar_diversidad(dataset, extraer_cat_soporte)
    res["diversidad"] = {"balanced": d["balanceado"], "cv": d["longitud"]["cv"],
                         "ok": d["balanceado"] and d["longitud"]["cv"] > 0.3}
    errores_fmt = sum(1 for e in dataset if not all(f in e for f in ["instruction", "input", "output"]))
    res["formato"] = {"errores": errores_fmt, "ok": errores_fmt == 0}
    res["listo"] = all(v["ok"] for v in res.values() if isinstance(v, dict))
    return res

v = validar_para_training(final)
print("Resultados:")
for k in ("tamano", "calidad", "diversidad", "formato"):
    print(f"  {k}: {'✅' if v[k]['ok'] else '❌'}")
print("\nListo para entrenar." if v["listo"] else "\n⚠️ Corrige antes de entrenar.")
```

### Guardar en JSONL para el trainer

```python
import json

def guardar_jsonl(dataset, ruta):
    with open(ruta, "w", encoding="utf-8") as f:
        for ex in dataset:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

guardar_jsonl(train, "data/soporte_train.jsonl")
guardar_jsonl(val, "data/soporte_val.jsonl")
```

## Ejemplo con código

Pipeline end-to-end integrado:

```python
# pipeline completo
raw = json.load(open("data/soporte_raw.json"))
clean = eliminar_duplicados(raw)
reporte = evaluar_calidad(clean, custom)
div = analizar_diversidad(clean, extraer_cat_soporte)

# Si hay categorías con menos del 10%, generamos sintéticos
if not div["balanceado"]:
    sinteticos = generar_desde_templates(templates_devolucion, pools, 50)
    val_sint = validar_sinteticos(sinteticos, clean)
    final = crear_dataset_mixto(clean, val_sint["ok"], ratio_sint=0.25)
else:
    final = clean

train, val = split_train_val(final, 0.1)
chk = validar_para_training(final)
assert chk["listo"], "Dataset no está listo"

guardar_jsonl(train, "data/soporte_train.jsonl")
guardar_jsonl(val, "data/soporte_val.jsonl")
print(f"✅ {len(train)} train / {len(val)} val listos para fine-tuning.")
```

## Errores comunes

- **Dataset demasiado pequeño.** Menos de 500-2,000 ejemplos lleva a underfitting en tareas moderadas. Genera sintéticos si no puedes recolectar más.
- **Calidad baja no detectada.** Un dataset con 80% de calidad enseña 20% de patrones incorrectos. Pon un threshold estricto (≥90%).
- **Falta de diversidad.** Todos los ejemplos cortos y de baja urgencia → modelo falla ante casos complejos.
- **Clases desbalanceadas.** 70% envíos y 5% facturación → modelo favorece envíos sistemáticamente. Rebalancea con sintéticos o oversampling.
- **Sintéticos sin validar.** Añadir texto generado sin verificar formato, longitud o duplicados degrada el modelo.
- **Más del 40% de datos sintéticos.** El modelo aprende el estilo del generador (ej. GPT-4) en lugar de tus datos reales.
- **No separar validación.** Sin val set no detectas overfitting. Mínimo 10% para val.
- **Val set contaminado.** Si un ejemplo (o uno casi idéntico) está en train y val, la métrica miente. Deduplica antes de hacer split.
- **No guardar en JSONL.** JSON monolítico es incómodo para streaming y shuffling.
- **No fijar `seed`.** Cada ejecución produce splits distintos → resultados no reproducibles.

## Resumen

- La preparación de dataset es **el 60-80% del trabajo real** de fine-tuning.
- Evalúa en 5 dimensiones: **completeness, accuracy, consistency, relevance, diversity**.
- Pipeline estándar: inspección → deduplicación → calidad → diversidad → sintéticos → validación → split train/val → guardar JSONL.
- Genera sintéticos cuando falte cobertura; usa **templates** para patrones estructurados y **LLM-guided** para casos complejos.
- Mantén el ratio sintético **entre 20-30%** y nunca por encima del 40%.
- Automatiza la validación: si la calidad cae debajo de un threshold, no entrenes.
- Para el chatbot de soporte, 2,000 reales + 500 sintéticos (25%) con calidad ≥90% y categorías balanceadas es un dataset sólido.
- Fija semillas, versiona los datasets (DVC, Git LFS) y guarda el reporte de validación junto con el modelo.
