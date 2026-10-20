# Actividad 02 — Policy custom en Checkov (Python)

## 1. Identificación

- **ID:** `sec-07-02-custom-checkov-policy`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-07-iac-scanning-checkov-trivy-config-tfsec`
- **Dificultad:** intermediate
- **Duración estimada:** 40–50 min
- **Tipo:** independent (no depende de la actividad 01)

## 2. Contexto

Tu organización tiene una convención propia: **todo bucket S3 debe tener el tag `data_classification`** con un valor del conjunto `{public, internal, confidential, restricted}`. Ninguna regla built-in de Checkov cubre eso — es dominio tuyo. Vas a escribir una **policy custom en Python** que lo detecte, con fixtures buenos y malos.

## 3. Objetivos

- Escribir una policy Checkov Python que extienda `BaseResourceCheck`.
- Nombrar el check con un ID con prefijo organizacional (`CKV_ACME_1`) para no colisionar.
- Montar fixtures `good.tf` (tag presente y válido) y `bad.tf` (tag ausente o valor fuera de la enum).
- Correrla con `checkov --external-checks-dir`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §7.
- Herramientas: `python3`, `bash`.
  - **Opcional**: `checkov` (`pip install checkov`). Si no está, el validador degrada: comprueba estructura e importa la policy con `python -c` para asegurar que al menos no explota.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar workspace

```bash
mkdir -p /tmp/sec-07-custom-policy
cp -r starter/* /tmp/sec-07-custom-policy/
cd /tmp/sec-07-custom-policy
```

### 5.2 Leer y completar la policy

Abre `checks/BucketMustHaveClassification.py`. La estructura ya está. Verás:

- Clase que hereda de `BaseResourceCheck`.
- Metadata (`id`, `name`, `categories`, `supported_resources`).
- Método `scan_resource_conf(self, conf)` donde está la lógica.

Tu trabajo:

1. Asegúrate de que la enum `ALLOWED_CLASSIFICATIONS` cubre al menos los 4 valores canónicos.
2. En `scan_resource_conf`:
   - Si el recurso no tiene `tags` → `CheckResult.FAILED`.
   - Si tiene `tags` pero sin `data_classification` → `CheckResult.FAILED`.
   - Si tiene `data_classification` con valor fuera de la enum → `CheckResult.FAILED`.
   - Si todo bien → `CheckResult.PASSED`.

La forma de `conf.get("tags")` en Checkov puede ser `[{...}]` (lista con un dict) o `[{"key1":[...]}]` dependiendo del parser — maneja ambos.

### 5.3 Fixtures

Ya hay dos:

- `fixtures/good.tf` — bucket con `data_classification = "internal"`. Debe **PASAR**.
- `fixtures/bad.tf` — tres buckets inseguros (sin tags, con `data_classification` fuera de enum, con otros tags pero sin `data_classification`). Deben **FALLAR**.

Si quieres, añade un cuarto caso: bucket con `data_classification = ""` (string vacío) → debe fallar.

### 5.4 Correr

```bash
# Si tienes checkov instalado:
checkov -d fixtures/ --external-checks-dir ./checks --check CKV_ACME_1

# Si no, al menos verifica que importa:
python3 -c "import sys; sys.path.insert(0, 'checks'); import BucketMustHaveClassification; print('OK')"
```

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/sec-07-custom-policy
```

## 6. Resultado esperado

- `checks/BucketMustHaveClassification.py` existe, importa limpio, y define una clase que hereda de `BaseResourceCheck` con `id = "CKV_ACME_1"`.
- Hay al menos **2 fixtures** (`good.tf`, `bad.tf`).
- Si `checkov` está instalado: `good.tf` pasa la policy y `bad.tf` dispara al menos un FAILED.
- `bash tests/validate.sh` → verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador verde; si Checkov está, el smoke test con fixtures pasa el "pass vs fail" esperado.
- **Degradación graciosa**: todo pasa sin `checkov` instalado (validador comprueba estructura e import).
- **Reproducibilidad**: borrar y repetir produce el mismo resultado.
- **Convenciones**: ID con prefijo organizacional, no colisiona con Checkov built-in.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-07-custom-policy
```

## 9. Preguntas de reflexión

1. ¿Por qué prefijar el ID con `CKV_ACME_` y no con `CKV_AWS_`?
2. ¿Qué pasa si Checkov cambia la forma del `conf` entre versiones mayores? ¿Cómo lo detectarías?
3. ¿Preferirías escribir esta regla en **Rego** o en **Python**? ¿Por qué?
4. Esta policy detecta ausencia de tag — ¿cómo la convertirías en "el tag existe **y** su valor está en una lista permitida"?
5. ¿En qué momento esta policy custom debe convertirse en **built-in** de tu organización (p. ej. pack interno)?

## 10. Extensiones

- Añade un segundo check: **CKV_ACME_2** — "todo bucket debe tener `logging` configurado" (ya existe `CKV_AWS_18` built-in; el ejercicio es escribirlo tú para practicar).
- Convierte la policy a Rego y córrela con `--external-checks-dir`.
- Escribe un pytest que importe la clase y la ejecute contra fixtures sintéticos.

## 11. Limpieza

```bash
rm -rf /tmp/sec-07-custom-policy
```
