# REFERENCE — sec-07-02-custom-checkov-policy

> Una referencia razonada. No es la única respuesta correcta.

## Policy (resuelta)

Ver `checks/BucketMustHaveClassification.py`. Puntos a entender:

- **`ID = "CKV_ACME_1"`**: el prefijo `CKV_ACME_` es un espacio de nombres de tu organización. Nunca empezaría con `CKV_AWS_` porque colisionaría con los IDs built-in de Checkov.
- **`supported_resources`**: lista cerrada. Checkov solo invoca `scan_resource_conf` sobre `aws_s3_bucket`.
- **`scan_resource_conf(conf)`**: Checkov te entrega el bloque parseado. La forma puede variar (lista con un dict, dict directo). Siempre defensivo.
- **4 casos de fallo**: sin tags, sin `data_classification`, valor fuera de enum, string vacío. Todos modelados en `bad.tf`.
- **Try/except ImportError**: permite que la policy se importe sin Checkov instalado — el validador verifica import sin requerir toda la toolchain.

## Smoke test manual

```bash
cd /tmp/sec-07-custom-policy
checkov -d fixtures/ --external-checks-dir ./checks --check CKV_ACME_1
```

Salida esperada (abreviada):

```
checkov_version: ...
Passed checks: 1, Failed checks: 3

Check: CKV_ACME_1: "S3 bucket must have data_classification tag with an allowed value"
  PASSED for resource: aws_s3_bucket.ok
  File: fixtures/good.tf

  FAILED for resource: aws_s3_bucket.no_tags       (fixtures/bad.tf)
  FAILED for resource: aws_s3_bucket.wrong_tags    (fixtures/bad.tf)
  FAILED for resource: aws_s3_bucket.weird_value   (fixtures/bad.tf)
```

## Decisiones clave

1. **Enum literal vs regex**: enum es más legible y más fácil de evolucionar. Un regex `^(public|internal|...)$` es equivalente, pero esconde la intención.
2. **Fallo cerrado (default FAILED)**: cualquier forma inesperada del `conf` → FAILED. En seguridad, "fail closed" es la regla por defecto.
3. **Try/except ImportError**: hace que la policy sea testeable estructuralmente sin instalar la toolchain completa. Esencial para pipelines en máquinas sin Checkov.

## Si quieres ir más allá

- Añadir una enum externa (YAML cargado al construir el check) para que la lista permitida sea configurable sin tocar código.
- Añadir pytest unitarios que llamen `scan_resource_conf` con dicts sintéticos (no requiere ejecutar `checkov` entero).
- Empaquetar `checks/` como un **pack interno** de la org y distribuirlo vía repo privado + `pip install`.
