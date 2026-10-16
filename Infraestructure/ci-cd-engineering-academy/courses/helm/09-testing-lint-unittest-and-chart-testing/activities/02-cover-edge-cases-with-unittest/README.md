# Actividad 02 — Cubre 5 edge cases de values con helm-unittest

## 1. Identificación

- **ID:** `helm-09-02-cover-edge-cases-with-unittest`
- **Tecnología:** `helm`
- **Módulo:** `helm-09-testing-lint-unittest-and-chart-testing`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

La mayoría de bugs de un chart están en los **edge cases de values**: `null`, lista vacía, flag booleano, override completo, defaults. Esta actividad te da un chart y te pide escribir **tú solo** una batería de tests `helm-unittest` que cubra los 5 casos canónicos.

El `starter/` contiene un chart `demo-app` con `Deployment`, `Service`, `Ingress` condicional y `HorizontalPodAutoscaler` condicional. **No incluye tests**. Tu trabajo: escribirlos.

Esto es *independent*: no vas a seguir pasos pequeños, vas a diseñar la suite entera.

## 3. Objetivos

Al terminar deberías poder:

- Escribir `tests/*_test.yaml` cubriendo los 5 edge cases listados abajo.
- Usar los asserts `equal`, `notEqual`, `contains`, `notContains`, `exists`, `notExists`, `isKind`, `hasDocuments`, `isNull`.
- Agrupar tests por template (`deployment_test.yaml`, `ingress_test.yaml`, `hpa_test.yaml`).

## 4. Prerrequisitos

- `helm` ≥ 3.14 (si lo tienes — la validación estructural funciona sin él).
- Plugin `helm-unittest`:
  ```bash
  helm plugin install https://github.com/helm-unittest/helm-unittest
  ```

**Costos**: cero.

## 5. Instrucciones

### 5.1 Prepara el directorio

```bash
rm -rf /tmp/helm-09-02
mkdir -p /tmp/helm-09-02
cp -r starter/* /tmp/helm-09-02/
cd /tmp/helm-09-02
```

### 5.2 Lee el chart

Examina:

- `demo-app/values.yaml` — el contrato.
- `demo-app/templates/deployment.yaml` — tiene `extraEnv` opcional.
- `demo-app/templates/ingress.yaml` — se renderiza solo si `ingress.enabled && ingress.hosts`.
- `demo-app/templates/hpa.yaml` — se renderiza solo si `autoscaling.enabled`.

### 5.3 Escribe los tests

Crea archivos en `demo-app/tests/` que cubran los **5 edge cases**. Cada caso debe tener **al menos un assert** no trivial (más allá de `isKind`):

| # | Edge case | Qué testear |
|---|-----------|-------------|
| 1 | Default values | Sin pasar nada, el `Deployment` sale con `replicas: 1` e `image: nginx:1.27`. |
| 2 | Override completo | Con `image.repository=foo` y `image.tag=bar`, el container tiene `image: "foo:bar"`. |
| 3 | Lista vacía | Con `extraEnv: []`, el container **no** tiene campo `env:` (o lo tiene vacío sin romper indentación). |
| 4 | Nil | Con `ingress.enabled: true` pero `ingress.hosts: null`, **no** se renderiza Ingress. |
| 5 | Flag booleano | Con `autoscaling.enabled: false` no hay HPA; con `true`, sí hay HPA con los valores por default. |

Puedes repartirlos en 3 archivos (`deployment_test.yaml`, `ingress_test.yaml`, `hpa_test.yaml`).

### 5.4 Corre los tests

```bash
helm unittest demo-app
```

Deberías ver todos en verde. **Si no tienes el plugin instalado**, el validador acepta la ausencia pero verifica que los archivos de test existen y tienen la estructura esperada.

### 5.5 Valida estructura

```bash
bash tests/validate.sh /tmp/helm-09-02
```

## 6. Resultado esperado

- `/tmp/helm-09-02/demo-app/tests/*_test.yaml` con tests cubriendo los 5 edge cases.
- `helm unittest demo-app` corre en verde (si tienes el plugin).
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] Al menos **5 bloques `- it:`** en total.
- [ ] Al menos un test con `set:` que use `[]` (lista vacía).
- [ ] Al menos un test con `set:` que use `null` o `isNull`.
- [ ] Al menos un test con `hasDocuments: { count: 0 }` o `hasDocuments: { count: 1 }`.
- [ ] Al menos un assert `equal` con un `path:` a un string de imagen (`.image` o similar).
- [ ] Al menos un test con un flag booleano en `set:` (ej. `autoscaling.enabled: true`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/helm-09-02
```

Si tienes `helm` + plugin, el validador también intenta `helm unittest demo-app` como señal adicional (opt-in, no bloqueante).

## 9. Preguntas de reflexión

1. En el test de "lista vacía", ¿por qué es importante distinguir "no aparece el campo" de "aparece como `env: []`"? ¿Qué efecto tiene cada uno en Kubernetes?
2. ¿Qué pasaría si en el template `deployment.yaml` cambiaras `{{- with .Values.extraEnv }}` por `{{- if .Values.extraEnv }}`? Diseña un test que detecte la diferencia.
3. ¿Por qué `hasDocuments: { count: 0 }` es un assert válido? ¿Qué validaría un `hasDocuments: { count: 1 }` que un simple `isKind` no validaría?
4. Encuentra un edge case que **no esté** en los 5 anteriores y que valga la pena testear.

## 10. Extensiones

- **E1** — Añade un test de `failedTemplate` que verifique que si pasas `image.repository: ""`, el render falla con un mensaje predecible (requiere añadir `required` al template).
- **E2** — Añade un snapshot test al Service.
- **E3** — Añade un test que compruebe que los labels estándar (`app.kubernetes.io/name`, `app.kubernetes.io/instance`) están presentes en todos los recursos.

## 11. Limpieza

```bash
rm -rf /tmp/helm-09-02
```
