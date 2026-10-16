# Actividad 01 — Provocar y detectar un shell en un Pod

## 1. Identificación

- **ID:** `sec-12-01-trigger-and-detect-shell-in-pod`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-12-runtime-security-falco-and-tetragon`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** scenario

## 2. Contexto

Un atacante (interno o externo con credenciales robadas) consigue `kubectl exec` sobre un Pod de aplicación y abre un shell. Dentro, intenta leer `/etc/shadow`. Esta es la **primera** señal que Falco debería capturar; sin ella, probablemente la intrusión pasa desapercibida hasta que hay daño.

Tu trabajo:

1. Reproducir el escenario (o leer el JSON pre-generado).
2. Analizar la alerta.
3. Escribir el **runbook** que tu equipo seguiría.

## 3. Objetivos

- Desplegar Falco en `kind` **o** usar `sample-events.json` si tu entorno no lo permite.
- Parsear el evento JSON y extraer: `rule`, `priority`, `k8s.pod.name`, `container.image.repository`, `user.name`, `proc.cmdline`.
- Decidir si esta clase de alerta debería promoverse a enforcement con Tetragon y defender la respuesta.
- Entregar `DETECTION.md` con 4 secciones y un runbook de 5 pasos.

## 4. Prerrequisitos

- Lección `theory/lesson.md` leída (§3, §4, §5, §7, §8).
- Ejemplo `examples/01-falco-in-cluster/` revisado.
- Opcional pero recomendado: `kind`, `kubectl`, `helm` instalados.

Si **no** tienes `kind`, usa el camino walkthrough (sección 5.2).

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-12-detect
cd /tmp/sec-12-detect
```

### 5.2 Camino A — Con `kind` (preferido)

```bash
# Ajusta la ruta del repo:
REPO=/ruta/al/repo
bash "$REPO/courses/devsecops/12-runtime-security-falco-and-tetragon/examples/01-falco-in-cluster/setup.sh"

# Provoca el evento:
kubectl run attacker --image=alpine --restart=Never -- sleep 3600
kubectl exec -it attacker -- sh -c "cat /etc/shadow; exit"

# Captura los eventos de Falco a JSON:
kubectl -n falco logs ds/falco --tail=200 \
  | grep -E 'Terminal shell in container|Read sensitive file' \
  > /tmp/sec-12-detect/raw-events.log
```

Si el DaemonSet no arranca por el driver kernel: pasa al camino B.

### 5.3 Camino B — Walkthrough (sin cluster)

Copia los eventos pre-generados:

```bash
REPO=/ruta/al/repo
cp "$REPO/courses/devsecops/12-runtime-security-falco-and-tetragon/examples/01-falco-in-cluster/sample-events.json" \
   /tmp/sec-12-detect/raw-events.json
```

El entregable es exactamente el mismo. Si tu validador no encuentra `raw-events.log` buscará `raw-events.json`.

### 5.4 Escribir `DETECTION.md`

Crea `/tmp/sec-12-detect/DETECTION.md` con **estas cuatro secciones** (los títulos aparecerán tal cual en el validador estructural):

```markdown
# DETECTION — shell en Pod

## Seccion A — Evento

- Regla: ...
- Prioridad: ...
- Pod: ...
- Imagen: ...
- Usuario: ...
- Cmdline: ...

(Rellena con los campos extraidos del evento JSON de Falco.)

## Seccion B — Analisis

- Que ocurrio en una frase:
- Que ancestros muestra el evento (proc.pname / proc.aname) y que significa:
- Como diferencias esto de un debug operativo legitimo:
- Que otras alertas correlacionadas deberias esperar:

## Seccion C — Runbook (5 pasos minimo, numerados)

1. ...
2. ...
3. ...
4. ...
5. ...

## Seccion D — Decision: detect vs enforce

- Recomendacion para la regla 'Terminal shell in container': detect / enforce / depende.
- Justificacion (menciona Falco, Tetragon y riesgo de falso positivo):
- Si eliges enforce, cual seria la TracingPolicy minima:
```

### 5.5 Validar la estructura

```bash
REPO=/ruta/al/repo
bash "$REPO/courses/devsecops/12-runtime-security-falco-and-tetragon/activities/01-trigger-and-detect-shell-in-pod/tests/validate.sh" /tmp/sec-12-detect
```

### 5.6 Autoevaluación

Compara tu `DETECTION.md` con `solution/REFERENCE.md`.

## 6. Resultado esperado

- Existe `/tmp/sec-12-detect/DETECTION.md`.
- Las cuatro secciones aparecen con sus títulos.
- La Sección A nombra la regla `Terminal shell in container` **o** `Read sensitive file untrusted` y menciona Pod + imagen + usuario + cmdline.
- La Sección C tiene **al menos 5 pasos numerados**.
- La Sección D nombra Falco **y** Tetragon.
- El validador estructural pasa.

## 7. Criterios de aceptación

- **Funcional**: evento provocado (camino A) o parseado (camino B).
- **Analítico**: el runbook es ejecutable por otra persona.
- **Operacional**: la decisión detect/enforce está defendida; no es "porque sí".

## 8. Preguntas de reflexión

1. ¿Por qué `kubectl exec` genera el evento Falco "shell in container" aunque la operación venga del plano de control?
2. ¿Cómo correlacionarías la alerta con el audit log del API server para saber **quién** invocó el exec?
3. Si tu organización usa `kubectl exec` legítimamente a diario (debug), ¿cómo evitarías que la regla sea ruido? Da dos opciones.
4. ¿En qué caso promoverías esta regla a enforcement con Tetragon? ¿Qué riesgos aceptas?
5. ¿Qué agregaría Falcosidekick que hoy no tengas con solo `kubectl logs`?

## 9. Limpieza

```bash
# Si usaste el camino A:
kubectl delete pod attacker --ignore-not-found
helm uninstall -n falco falco || true
kind delete cluster --name sec-12-demo || true
# En todos los casos:
rm -rf /tmp/sec-12-detect
```
