# k8s-05-01 — Config y Secret para la app del capstone

## 1. Identificación

- **ID:** `k8s-05-01-config-and-secret-for-capstone`
- **Tecnología:** kubernetes
- **Módulo:** `05-config-secrets-env-volumes-basics`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Tu app del capstone necesita dos cosas distintas para arrancar:

- **Configuración no sensible**: `LOG_LEVEL`, `APP_PORT`, `GREETING`. Candidata obvia a `ConfigMap` + `envFrom`.
- **Credencial sensible**: `DB_PASSWORD`. Candidata obvia a `Secret` + volumen montado como archivo (**no** como env var — ya viste por qué en el ejemplo 02).

En esta actividad montas los dos recursos, los conectas al Deployment de la app, y verificas en vivo que:

1. La config aparece en el `env` del Pod.
2. La password **no** aparece en el `env` del Pod.
3. La password sí es legible como archivo (`/etc/app/secret/db-password`) con mode `0400`.
4. La app imprime cuánto mide la password (para probar que la leyó) sin imprimirla.

## 3. Objetivos

Al terminar deberías poder:

- Crear ConfigMap con `--from-literal` y aplicarlo con `kubectl apply`.
- Crear Secret `Opaque` con `--from-literal` (valores dummy) y aplicarlo igual.
- Escribir un Deployment que:
  - Consuma ConfigMap vía `envFrom`.
  - Monte el Secret como archivo en `/etc/app/secret/` con `defaultMode: 0400`.
- Verificar que la password **no** aparece en `env`.
- Validar todo con `tests/validate.sh`.

## 4. Prerrequisitos

- `kind` ≥ 0.23 y `kubectl` ≥ 1.28 en `PATH`. Verifica: `kind version`, `kubectl version --client`.
- Docker daemon arriba (kind lo necesita).
- 2 GB RAM libres para el cluster kind.
- Sin costo (todo local).
- Puertos del host no son necesarios (no publicamos nada hacia afuera).

## 5. Instrucciones

Trabaja en `/tmp/k8s-05-01/`:

```bash
mkdir -p /tmp/k8s-05-01 && cd /tmp/k8s-05-01
```

### Paso 1 — cluster kind si no tienes uno

```bash
kind get clusters | grep -qx k8s-05 || kind create cluster --name k8s-05
kubectl cluster-info --context kind-k8s-05
kubectl create namespace capstone --dry-run=client -o yaml | kubectl apply -f -
```

### Paso 2 — ConfigMap `app-config`

Crea un ConfigMap llamado **exactamente** `app-config` en el namespace `capstone` con estas claves:

- `LOG_LEVEL=info`
- `APP_PORT=8080`
- `GREETING=hola capstone`

Puedes usar `kubectl create configmap ... --dry-run=client -o yaml | kubectl apply -f -` o escribir el YAML a mano.

### Paso 3 — Secret `db` (Opaque, dummy)

Crea un Secret llamado **exactamente** `db` en el namespace `capstone` con:

- `username=app`
- `password=dummy-not-real-ABC123`

Valores **dummy**: nunca uses credenciales reales en labs.

### Paso 4 — Deployment `app`

Crea un Deployment llamado `app` que:

- `replicas: 1`.
- Imagen: `python:3.12-alpine`.
- `command: ["python","-c"]` ejecutando el script que viene en `starter/app.py` **inline** (cópialo al `args:` del container). El script:
  - Lee `LOG_LEVEL`, `APP_PORT`, `GREETING` del env.
  - Lee la password del archivo `/etc/app/secret/db-password`.
  - Imprime una línea JSON con esos valores y el tamaño de la password (no la password misma).
  - Luego hace `sleep` para quedar corriendo.
- Monta el Secret `db` como volume en `/etc/app/secret`, con la clave `password` renombrada a `db-password`, `defaultMode: 0400`.
- Consume `app-config` con `envFrom`.
- **No** inyecta la password como env var. (El validador lo verifica.)

En `solution/deployment.yaml` tienes una versión de referencia por si te atascas, pero intenta sin mirar primero.

### Paso 5 — aplicar y esperar

```bash
kubectl -n capstone apply -f deployment.yaml
kubectl -n capstone rollout status deploy/app --timeout=120s
```

### Paso 6 — verificar manualmente

```bash
POD=$(kubectl -n capstone get pod -l app=app -o jsonpath='{.items[0].metadata.name}')

# La config debe estar como env:
kubectl -n capstone exec "$POD" -- sh -c 'env | sort | grep -E "^(LOG_LEVEL|APP_PORT|GREETING)="'

# La password NO debe estar como env:
kubectl -n capstone exec "$POD" -- sh -c 'env | grep -c -i password || echo "0 (ningún env con password)"'

# La password SÍ debe estar como archivo mode 0400:
kubectl -n capstone exec "$POD" -- ls -la /etc/app/secret/db-password

# Y los logs deben tener la línea JSON con password_len=21 (len de "dummy-not-real-ABC123"):
kubectl -n capstone logs "$POD" | tail -5
```

### Paso 7 — validar

```bash
bash /ruta/al/repo/courses/kubernetes/05-config-secrets-env-volumes-basics/activities/01-config-and-secret-for-capstone/tests/validate.sh
```

## 6. Resultado esperado

- Deployment `app` con 1 réplica Ready.
- `kubectl exec` imprime los 3 env vars del ConfigMap.
- `env | grep -c -i password` imprime `0 (ningún env con password)`.
- `/etc/app/secret/db-password` existe con mode `0400` y contenido `dummy-not-real-ABC123`.
- Los logs incluyen una línea con `"password_len": 21`.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- La password **no** aparece en el env del Pod ni en `describe pod`.
- `defaultMode` del volumen Secret es `0400` (verifica con `kubectl get pod -o yaml`).

## 8. Validación

```bash
bash courses/kubernetes/05-config-secrets-env-volumes-basics/activities/01-config-and-secret-for-capstone/tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si el ConfigMap `app-config` cambia `LOG_LEVEL=debug`, ¿tu app lo verá en vivo? ¿Por qué?
2. ¿Qué pasaría si cambias `defaultMode: 0400` a `0644`? ¿Qué atacantes se habilitan?
3. Monta el Secret también como `envFrom`. Verifica que ahora `env | grep -i password` lo filtra. ¿Qué otras rutas de leak se abren?
4. ¿Qué tendrías que cambiar para que esta app lea la password desde AWS Secrets Manager en producción sin tocar su código?

## 10. Extensiones

- Convierte el consumo a un `projected volume` que agrupe ConfigMap + Secret + un `downwardAPI` con `metadata.labels`.
- Añade un `initContainer` que valide el formato de la password (longitud ≥ 12) antes de arrancar el contenedor principal.
- Haz hot-reload: `kubectl -n capstone patch secret db --type merge -p '{"stringData":{"password":"otra-dummy-999"}}'` y verifica cuánto tarda el archivo en actualizarse.

## 11. Limpieza

```bash
kubectl delete namespace capstone --wait=false
rm -rf /tmp/k8s-05-01
# Si creaste el cluster solo para esto:
# kind delete cluster --name k8s-05
```
