# Actividad 01 — ADR corto: cuándo Kubernetes NO es la respuesta

## 1. Identificación

- **ID:** `k8s-01-01-when-is-k8s-overkill`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-01-mental-model-and-architecture`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

K8s es *el* estándar de orquestación, y por eso se adopta a menudo **sin ingeniería crítica**: "porque todos lo usan", "porque CV", "porque algún día escalaremos". Esta actividad entrena el músculo contrario: **defender razonadamente que NO lo necesitas** en un escenario dado.

El entregable es un **ADR** (Architecture Decision Record) corto en Markdown, con el formato estándar: Contexto / Decisión / Consecuencias / Alternativas descartadas. Es el documento que un lead escribiría en el repo del equipo para que la decisión quede registrada.

No se requiere cluster, ni `kubectl`, ni cloud. Es puramente conceptual y de criterio.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Articular **cuándo** K8s tiene sentido y cuándo no, con criterios **medibles** (tráfico, nodos, equipo, dominio).
- Nombrar **al menos 3 alternativas** concretas a K8s para el escenario planteado y por qué cada una encajaría/no.
- Reconocer el **costo total** de K8s más allá de "pagar unos nodos": ingeniería de plataforma, upgrades, policy, observabilidad, formación.
- Escribir un ADR corto y defendible.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (especialmente §7, §8, §9).
- Haber recorrido `examples/01-draw-control-plane/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/k8s-01-overkill
cd /tmp/k8s-01-overkill
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/k8s-01-overkill`.)

### 5.2 Escenario (ficticio pero realista)

> **Startup "Panadería SaaS"**. Equipo de 4 personas (2 backend, 1 frontend, 1 "DevOps a medias"). Producto: un pequeño SaaS B2B para gestionar pedidos y stock de panaderías. Stack: un backend FastAPI, un frontend Next.js, un Postgres gestionado (RDS). Tráfico: ~200 peticiones/minuto en pico, ~50 clientes de pago. Un VPS en DigitalOcean con Docker Compose les ha bastado los últimos 18 meses. El CTO escuchó en una conferencia que "sin K8s no escalarán" y propone migrar.
>
> Tu tarea: escribir un ADR corto argumentando **si deberían o no adoptar K8s hoy**. Puede ser "sí" o "no" — lo que importa es el razonamiento. (El ADR de referencia argumenta "no, todavía no" para calibrar.)

### 5.3 Entregable: `ADR.md`

Produce un archivo `ADR.md` con **cuatro secciones** explícitas (estilo ADR estándar):

#### A. Contexto

Describe en 5–10 líneas el escenario (puedes copiarlo y resumirlo). Incluye explícitamente los datos relevantes para la decisión:

- Tamaño del equipo.
- Tráfico y número de servicios.
- Estado actual (Docker Compose + VPS funciona).
- Postgres ya está managed (fuera del scope de K8s).
- Equipo sin experiencia previa en K8s en producción.

#### B. Decisión

Enuncia **claramente** qué recomiendas y una frase que lo resuma. Formato:

```
Decidimos NO adoptar Kubernetes en este momento. Mantendremos
Docker Compose sobre VPS y revisaremos la decisión cuando se
cumpla alguno de los disparadores de la sección C.
```

(Si prefieres defender "sí", es válido — pero el ADR tendrá que mostrar que el equipo cuenta con la ingeniería de plataforma necesaria y que hay un driver concreto.)

#### C. Consecuencias y disparadores

Dos sub-partes:

- **Consecuencias de la decisión**: qué ganas y qué pierdes. Por ejemplo, no adoptar K8s ahorra ingeniería de plataforma, pero el equipo seguirá con un bus-factor alto en el VPS y sin estándar de rollout sin downtime.
- **Disparadores (triggers) para revisar la decisión**: lista de condiciones **concretas y medibles** que, si se cumplen, obligarían a reconsiderar. Al menos **5**:
  - Tráfico sostenido > X RPS o > N instancias necesarias.
  - Equipo crece a > N ingenieros con necesidad de aislar entornos.
  - Más de M servicios independientes con ciclos de vida distintos.
  - Requisito de rollouts sin downtime para múltiples servicios.
  - Requisitos regulatorios que exijan NetworkPolicies o auditoría tipo cluster.
  - Necesidad de autoscaling fino basado en métricas custom.

#### D. Alternativas descartadas

Lista **al menos 3** alternativas evaluadas y por qué se descartan **hoy** (pero podrían volver con otros disparadores):

- **Mantener Docker Compose + VPS** (lo que ya tienen).
- **Managed K8s** (EKS/GKE/AKS).
- **Nomad** (orquestador más simple).
- **ECS** (AWS) o equivalente en el cloud elegido.
- **Cloud Run / App Runner** (PaaS sobre contenedores sin K8s).
- **Serverless puro** (Lambda / Cloud Functions) para endpoints concretos.

Para cada una: una frase de pros, una de contras, una de "cuándo sí".

### 5.4 Preguntas obligatorias (al final de `ADR.md`)

Numera las respuestas **del 1 al 7**:

1. ¿Cuál es el **costo oculto** más grande de adoptar K8s "porque sí" en una startup de 4 personas? Da un ejemplo concreto.
2. En el escenario dado, Postgres está en RDS (managed). ¿Qué parte del valor de K8s se pierde cuando el estado está fuera del cluster? Argumenta.
3. ¿Por qué `managed` K8s (EKS/GKE/AKS) **no elimina** la mayoría del costo? Nombra al menos 3 cosas que el proveedor **no** te resuelve.
4. Explica el antipatrón "adoptamos K8s para contratar mejor" — ¿en qué casos es defendible y en cuáles no?
5. Da un escenario concreto donde K8s **sí** sería la respuesta correcta para esta misma startup (puedes inventar el cambio de contexto necesario).
6. Compara, en tres líneas, "Docker Compose en una VM" vs "ECS Fargate" como alternativas intermedias **antes** de K8s.
7. ¿Qué disparador (de los que listaste en C) te obligaría a volver a abrir este ADR **primero**? ¿Cómo lo medirías?

### 5.5 Validar estructura

```bash
bash tests/validate.sh /tmp/k8s-01-overkill
```

Chequea que `ADR.md` exista y contenga las cuatro secciones mínimas (Contexto / Decisión / Consecuencias / Alternativas), menciones a conceptos clave (K8s, compose, managed, trigger/disparador, alternativa, etc.) y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/ADR-reference.md`.

## 6. Resultado esperado

- Archivo `ADR.md` en `/tmp/k8s-01-overkill/` con secciones Contexto / Decisión / Consecuencias / Alternativas y 7 respuestas numeradas.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/ADR-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Las cuatro secciones (Contexto / Decisión / Consecuencias / Alternativas) aparecen explícitas.
- [ ] Al menos **5 disparadores** medibles y concretos en la sección C.
- [ ] Al menos **3 alternativas** evaluadas en la sección D.
- [ ] Menciona explícitamente "managed" (EKS/GKE/AKS) y por qué no elimina el costo total.
- [ ] Las 7 preguntas respondidas (como `1.`, `2.`, ... al inicio de línea).

## 8. Validación

```bash
bash tests/validate.sh /tmp/k8s-01-overkill
```

Estructural. **Semántica** la calibras tú con `solution/ADR-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Si el escenario fuera **"50 ingenieros, 30 microservicios"**, ¿cambiaría tu decisión? ¿Por qué?
2. ¿Cuál es la señal más clara de que un equipo **todavía no está listo** para K8s aunque técnicamente lo necesite?
3. ¿Qué hace que una organización **nunca** necesite K8s? Argumenta con un ejemplo real que conozcas.

## 10. Extensiones (opcional)

- **E1** — Reescribe el ADR para el escenario inverso ("empresa de 200 personas con 80 microservicios en VMs, cada equipo con su propio script de deploy") y defiende la **adopción** de K8s.
- **E2** — Añade un apéndice "coste estimado a 12 meses" con cifras realistas (EKS control plane $0.10/h ≈ $73/mes, nodos, ingeniería, formación, Argo CD, observabilidad).
- **E3** — Investiga el término **"KubeMySQL"** (o similar) y explica por qué correr una DB stateful en K8s *puede* ser antipatrón para una startup pequeña.

## 11. Limpieza

```bash
rm -rf /tmp/k8s-01-overkill
```
