# Starter — gcp-06-01

Copia este directorio como punto de partida:

```bash
mkdir -p /tmp/gcp-06-cmek
cp -r starter/* /tmp/gcp-06-cmek/
```

Luego edita cada archivo siguiendo la guía de `../README.md`.

## Placeholders a mantener

- `project_id = "demo-cmek-example"` (ficticio).
- `project_number = "000000000000"` (ficticio; 12 ceros).
- `region = "europe-west1"`.

**Nunca** reemplaces por un project ID real. Esta actividad no se aplica.

## Dependencias de Python

```bash
python3 -m pip install --user cryptography
```

Verifica con:

```bash
python3 -c "import cryptography; print(cryptography.__version__)"
```
