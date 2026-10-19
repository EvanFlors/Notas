# Ejemplo 04 — Cloud Functions gen 2 (handler Python local)

## Que demuestra

- Un handler `handler(request)` compatible con **Cloud Functions gen 2** (HTTP trigger).
- Cloud Functions gen 2 **es Cloud Run** por debajo + el **Functions Framework** que envuelve tu handler como HTTP server.
- El mismo handler es ejecutable **local** con `functions-framework` sin desplegar nada.

## Prueba local

```bash
cd examples/04-cloud-functions-gen2-python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
functions-framework --target=handler --port=8081
```

En otra terminal:

```bash
curl -s "localhost:8081/?name=cloudrun"
# {"hello":"cloudrun"}
```

## Validar Terraform

```bash
terraform init -backend=false -input=false
terraform validate
```

El recurso Terraform usa `google_cloudfunctions2_function`, que internamente levanta un servicio Cloud Run.
