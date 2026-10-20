# Examen de certificación — Curso Ansible

- **Nivel:** intermedio-avanzado (cubre `ans-04` a `ans-10`, con base asumida en `ans-01..ans-03`).
- **Dimensiones evaluadas:** conceptual, operativa, arquitectónica (`todas`).
- **Duración objetivo:** 90–120 minutos.
- **Umbral de aprobación:** 70% ponderado sobre el total.
- **Entorno de evaluación:** take-home con corrector; el ejercicio operativo se corre contra `localhost` (sin cloud, sin hosts remotos). Si Ansible no está instalado en la máquina del estudiante, los tasks del ejercicio operativo deben marcarse como **SKIP justificado** y el estudiante debe entregar en su lugar la **transcripción esperada** de cada comando y los archivos solicitados.
- **Materiales permitidos:** documentación oficial de `ansible-core` y de collections; no se permite copiar/pegar bloques completos de blogs/LLMs sin atribución.
- **Prosa en español, código y nombres técnicos en inglés.**

Las referencias `C1..C12` apuntan a `competency-matrix.yaml`.

---

## Parte 1 — Preguntas conceptuales (35% del total)

> Respuesta corta: 4–8 líneas por pregunta salvo que se indique otra cosa. El corrector valora **el razonamiento**; una respuesta correcta sin justificación obtiene como máximo 50% del peso de la pregunta.

### Q1 — ¿Por qué Ansible sigue aportando frente a Terraform o imágenes inmutables? (C1, peso 6)

Un equipo plantea: "si tenemos Terraform para aprovisionar y Packer para hornear imágenes, Ansible ya no sirve". Da **dos escenarios concretos** donde Ansible sigue siendo la mejor herramienta y **uno** donde efectivamente no lo es, justificando con el modelo push-agentless-SSH-Python-en-target.

**Qué buscamos:** diferenciación CM vs IaC vs imágenes; reconocer Day-2 ops, bare metal, network devices, incident response, bootstrap kubeadm como territorio Ansible; reconocer que apps en Kubernetes o aprovisionamiento cloud puro no lo son.

### Q2 — Idempotencia real vs simulada (C2, peso 6)

El siguiente task se marca `changed` en cada corrida:

```yaml
- name: Ensure app directory initialized
  ansible.builtin.shell: "mkdir -p /opt/app && chown app:app /opt/app"
```

(a) Explica **por qué** se marca `changed` siempre. (b) Reescríbelo de **dos** maneras idempotentes distintas (una usando módulos nativos, otra manteniendo `shell` pero añadiendo las directivas apropiadas). (c) Explica qué garantía pierde cada alternativa frente a la otra.

### Q3 — Handlers y fallos a mitad de play (C3, peso 5)

(a) Describe cuándo corre un handler notificado y cuántas veces, aunque dos tasks distintas lo notifiquen. (b) Si una task posterior falla **después** del `notify` pero **antes** de que termine el play, ¿corre el handler? ¿Qué flag cambia ese comportamiento y qué riesgo introduce usarlo por defecto?

### Q4 — Precedence de variables (C4, peso 6)

Define `app_port`:

- `roles/app/defaults/main.yml` → `app_port: 8080`
- `group_vars/web.yml` → `app_port: 8000`
- `host_vars/web01.yml` → `app_port: 9000`
- Invocación: `ansible-playbook site.yml -e app_port=7000 --limit web01`

(a) ¿Qué valor toma `app_port` en `web01`? (b) Si moviéramos la definición del role a `roles/app/vars/main.yml`, ¿cambiaría la respuesta? Explica por qué, y cuándo es correcto poner algo en `vars/` en vez de `defaults/`.

### Q5 — Roles: cohesión, defaults vs vars, include vs import (C5, peso 5)

Un role `platform-bootstrap` instala Docker, nginx, PostgreSQL y configura usuarios de la empresa. (a) Critica el diseño en una frase. (b) Propón una descomposición mínima con nombres de role y responsabilidad de cada uno. (c) Para orquestar los nuevos roles desde un playbook, ¿cuándo preferirías `include_role` sobre `import_role`?

### Q6 — Collections y adopción responsable (C6, peso 4)

Tu equipo necesita un módulo de `community.foo` para un provider cloud. Enumera **cinco criterios objetivos** (no "me gusta") para decidir si adoptarla, y explica cómo materializas la decisión en el repo (archivos concretos y campos).

### Q7 — Por qué ansible-vault no basta en producción (C7, peso 6)

Un compañero propone cifrar todas las contraseñas de producción con `ansible-vault` y versionar los archivos cifrados. Da **tres razones técnicas** por las que esta estrategia **no escala** y describe cómo luciría la alternativa correcta (quién tiene el secret, cuándo se resuelve, cómo evitas que aparezca en logs).

### Q8 — ¿Cuándo serial, delegate_to, run_once, async? (C8, peso 6)

Para cada escenario, elige exactamente **una** directiva y justifica en una frase por qué las demás no son apropiadas:

1. Reiniciar nginx en 50 hosts, nunca más de 5 a la vez.
2. Crear un registro DNS en un servidor central tras agregar un nuevo host al balanceador.
3. Correr `dnf upgrade -y` que tarda 20 minutos sin bloquear la conexión SSH.
4. Insertar una línea en `/etc/hosts` **solo** en el primer host del grupo.

### Q9 — Qué garantiza (y qué no) la etapa `idempotence` de Molecule (C9, peso 5)

Molecule corre dos veces `converge` y falla si la segunda produce `changed > 0`. (a) ¿Qué defecto detecta exactamente esta etapa? (b) Nombra **dos** clases de bug del role que esta etapa **no** detecta. (c) ¿Qué etapa (`verify`, `lint`, …) sí los detectaría?

### Q10 — Contrato Ansible de la organización (C10, peso 6)

Define en no más de 10 líneas el "contrato Ansible" para una empresa que ya usa Terraform (cloud), Kubernetes (apps) y GitOps (deploy). Debe incluir: dónde Ansible **sí** se usa, dónde **no**, y qué pasa cuando un equipo intenta cruzar la frontera.

### Q11 — Mutable (TF+Ansible long-lived) vs inmutable (Packer+Ansible+TF) (C11, peso 5)

Da **un criterio** que incline la balanza hacia cada patrón, y explica qué deuda operacional contrae quien elige mutable sin disciplina.

### Q12 — `--check` y `--diff` como red de seguridad (C12, peso 3)

(a) ¿Qué tipo de módulo no soporta check mode y por qué eso puede dar una falsa sensación de "nada va a cambiar"? (b) ¿Cómo complementas `--check` para cubrir ese hueco?

---

## Parte 2 — Ejercicio operativo (40% del total)

Materiales de inicio en `operative/`. **El ejercicio corre contra `localhost` con el connection plugin `local`**; no se requieren hosts remotos, SSH, cloud, ni privilegios de root.

**Precondiciones:**

```bash
command -v ansible && ansible --version
```

Si `ansible-core` ≥ 2.16 **no** está disponible, el ejercicio se marca **SKIP justificado**: el estudiante entrega los archivos solicitados y una **transcripción escrita** de la salida esperada de cada comando, señalando en el reporte que el entorno no permitió ejecución.

### OP-task-1 — Inventory + ad-hoc (C12, 3 pts)

Dado `operative/inventory.yml`, lista los hosts del grupo `local` con `ansible-inventory` y ejecuta un `ping` contra ellos. **Entrega:** salida de ambos comandos y una frase explicando por qué `ping` del módulo `ansible.builtin.ping` **no** es ICMP.

### OP-task-2 — Convertir un playbook no idempotente (C2, 10 pts)

Toma `operative/bad_playbook.yml` (anti-patrón: usa `shell` para crear directorio, escribir archivo y "reiniciar" un servicio simulado). Produce `operative/good_playbook.yml` que:

1. Use módulos nativos (`file`, `copy`/`template`, `lineinfile` donde proceda).
2. Converja al mismo estado observable.
3. En una **segunda** ejecución reporte `changed=0` para todas las tasks.

**Validación automática:**

```bash
ansible-playbook -i operative/inventory.yml operative/good_playbook.yml       # primera corrida: changed > 0
ansible-playbook -i operative/inventory.yml operative/good_playbook.yml       # segunda corrida: changed == 0 en todas
```

Un script `operative/validate.sh` ejecuta ambas corridas y parsea el `PLAY RECAP` para verificar que la segunda tenga `changed=0`.

### OP-task-3 — Handler + template + patrón avanzado (C8, 7 pts)

Añade al `good_playbook.yml`:

1. Un **template** Jinja2 que genere `/tmp/ans-exam/app.conf` con `app_port` y `app_env` tomados de variables.
2. Un **handler** `restart app` que simule el reinicio (`debug: msg="would restart"`), **notificado solo** si cambia el archivo de config.
3. Un bloque `block/rescue/always` que capture un comando que puede fallar (`ansible.builtin.command: /usr/bin/false`), registre el error y continúe. En `always` deja constancia en un archivo `/tmp/ans-exam/run.log`.

### OP-task-4 — ansible-lint y check mode (C9, 5 pts)

Ejecuta sobre tu `good_playbook.yml`:

```bash
ansible-lint operative/good_playbook.yml
ansible-playbook -i operative/inventory.yml operative/good_playbook.yml --check --diff
```

**Entrega:** salida de ambos comandos y una nota (`operative/lint-notes.md`) explicando cada warning: si lo corregiste, cómo; si lo silenciaste con `# noqa`, por qué era correcto hacerlo.

### Validación completa del ejercicio operativo

```bash
bash operative/validate.sh
```

Debe terminar con `OK` o imprimir las diferencias esperadas. Si Ansible no está instalado, el script imprime `SKIP: ansible-core no disponible` y termina con exit code `0` (el estudiante entregará la justificación por escrito).

---

## Parte 3 — Ejercicio arquitectónico (25% del total)

Ver `architectural/scenario.md`.

El entregable es un **ADR** (Architecture Decision Record) que responde a un pedido conflictivo de otro equipo. Se evalúa el razonamiento, no la "respuesta correcta" (hay varias defendibles). Longitud: 400–800 palabras.

---

## 4. Rúbrica

### Preguntas conceptuales (todas)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Corrección técnica | Confunde conceptos clave (CM vs IaC, defaults vs vars, idempotencia vs no-op) | Correcto en lo esencial, con imprecisiones menores | Correcto y preciso; distingue casos borde | Correcto, preciso, y añade la limitación o contraejemplo que la pregunta no pide |
| Justificación | Afirmación sin razonamiento | Razonamiento superficial | Razonamiento causal explícito | Razonamiento con trade-off y alternativa descartada argumentada |
| Red flags evitadas | Comete una red flag de la lista | — | — | — (binario: cualquier red flag en la respuesta anula los puntos de la pregunta) |

Peso por pregunta según `competency-matrix.yaml`. Puntaje de la pregunta = (corrección + justificación) / 6 × peso.

### Ejercicio operativo

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) | Peso |
|---|---|---|---|---|---|
| Idempotencia real (OP-2) | 2ª corrida reporta `changed > 0` o rompe | Idempotente con `shell+changed_when: false` ocultando cambios | Idempotente con módulos nativos | Idempotente, con `check`/`diff` útil y comentario que justifica cada task | 30% |
| Handlers y patrones (OP-3) | Handler no corre o corre en cada run | Handler correcto; sin block/rescue útil | Handler + block/rescue + template parametrizado | Añade `no_log` donde aplica, usa `register`+`failed_when` razonado | 25% |
| Linter y check mode (OP-4) | Lint falla y no se adjunta salida | Lint limpio pero sin interpretación | Lint limpio, `--check` corre y explica diferencias | Explica qué warnings se silenciaron y por qué, y qué módulos no soportan check | 20% |
| Entregables y reproducibilidad | Archivos faltantes o rutas rotas | Entrega pero `validate.sh` requiere pasos manuales | `validate.sh` corre limpio o SKIP justificado por entorno | Añade README mínimo con prerequisitos y comandos | 15% |
| Seguridad y disciplina | Secretos en claro, `become` global | Sin secretos pero `become` sin justificación | `become` task-por-task, sin secretos | Documenta explícitamente que no hay secretos porque corre en localhost y qué cambiaría en remoto | 10% |

Umbral de aprobación del ejercicio operativo: **70% del peso**.

### Ejercicio arquitectónico (ADR)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) | Peso |
|---|---|---|---|---|---|
| Diagnóstico del requerimiento | No distingue CM de deploy de app K8s | Lo distingue sin consecuencias claras | Diagnóstico correcto con impacto operativo | Diagnóstico correcto, cita el contrato Ansible y los límites de ansible-vault | 25% |
| Decisión defendida | "Depende" sin criterio | Elige con un criterio | Elige con dos criterios y alternativa descartada | Elige con criterios reproducibles y define cuándo revisitarla | 25% |
| Trade-offs explícitos | Lista beneficios, oculta costos | Costos genéricos | Costos específicos (operación, seguridad, costo humano) | Trade-offs cuantificados o con señales medibles | 20% |
| Secretos y boundary | Permite ansible-vault como estrategia de prod | Reconoce el problema sin alternativa concreta | Propone secret manager externo con lookup | Diseña rotación, auditoría y camino de migración | 20% |
| Forma de ADR | No sigue estructura ADR | Estructura mínima | ADR completo (context, decision, consequences, alternatives) | ADR + fecha + estado + revisores + fecha de revisión | 10% |

Umbral de aprobación del ADR: **70% del peso**.

### Composición final

```
nota_total = 0.35 * conceptual + 0.40 * operativo + 0.25 * arquitectonico
aprueba si nota_total >= 70 y ningún ejercicio queda por debajo de 50 (regla anti-"sacar nota solo por un lado")
```

---

## 5. Guía de corrección (instructor-only)

### Respuestas modelo (resumen; expandir en revisión)

- **Q1:** Day-2 ops en VMs long-lived, incident response en bare metal, bootstrap de nodos K8s con `kubeadm`, dispositivos de red (Cisco/Junos) sin agent — buenos. Deploy de una app empaquetada en Helm chart — malo (Helm/GitOps lo hace mejor y más auditable).
- **Q2:** (a) `shell` no consulta estado; `mkdir -p` siempre reporta éxito pero Ansible lo marca `changed` porque no sabe si cambió. (b) Nativo: `ansible.builtin.file: path=/opt/app state=directory owner=app group=app`. Shell idempotente: `ansible.builtin.shell: mkdir -p /opt/app && chown app:app /opt/app args: creates: /opt/app`. (c) El nativo soporta check/diff y maneja permisos reconciliando estado; el shell con `creates` deja de ejecutarse pero no reconcilia permisos si el dir ya existe con dueño incorrecto.
- **Q3:** Handler corre una sola vez al final del play aunque N tasks lo notifiquen, en el orden definido (no en el orden de notificación). Si una task falla antes, el handler no corre; `--force-handlers` lo fuerza, pero puede dejar el host en estado parcial (p. ej. reinicia nginx con config aún no desplegada por una task fallida).
- **Q4:** (a) `7000` (extra vars gana). (b) Sí cambiaría si `vars/main.yml` fuera el que define: `vars/` del role tiene mayor precedence que `host_vars` y `group_vars` pero `-e` sigue ganando. `vars/` se usa para constantes de implementación del role que el usuario del role **no debe** cambiar; `defaults/` para contrato público sobrescribible.
- **Q5:** (a) Viola responsabilidad única; cualquier cambio toca todo. (b) `role-docker`, `role-nginx`, `role-postgres`, `role-company-users` + playbook orquestador. (c) `include_role` cuando el nombre del role depende de una variable o cuando necesita evaluarse condicionalmente en runtime; `import_role` cuando es estático (preferible por previsibilidad).
- **Q6:** namespace y mantenedor conocido, última release < 12 meses, issues/PRs atendidos, firma/certificación (Automation Hub), tests en el repo, cambios breaking documentados. En repo: `requirements.yml` con `version:` fijada + `ansible-galaxy collection install -r requirements.yml --upgrade=never` + commit del output de `ansible-galaxy collection list` o lockfile si disponible.
- **Q7:** (1) La password del vault se vuelve el secreto más valioso y acaba en CI vars. (2) No hay rotación nativa; rotar significa reescribir todos los archivos. (3) No hay audit log de "quién leyó qué". Alternativa: el secret vive en AWS Secrets Manager / Vault; Ansible usa `lookup('amazon.aws.secretsmanager_secret', ...)` o `community.hashi_vault.vault_kv2_get` en tiempo de ejecución; el runner usa workload identity (IAM role / OIDC); `no_log: true` en toda task que lo manipule.
- **Q8:** 1) `serial: 5`. 2) `run_once: true` + `delegate_to: dns.internal`. 3) `async: 1800 poll: 30` (o `poll: 0` + check posterior). 4) `run_once: true` (el primero del grupo).
- **Q9:** (a) Detecta tasks no idempotentes (shell sin creates, handlers que corren siempre, templates con contenido no determinista como timestamp). (b) No detecta: fallos cross-distro (eso lo cubre matrix CI), seguridad del contenido final (eso lo cubre `verify`/Testinfra/InSpec), bugs en `verify` mismo. (c) `verify` con asserts/Testinfra para estado final; matrix CI por distro para portabilidad; `ansible-lint` para antipatterns.
- **Q10:** Ansible SÍ: Day-2 ops en VMs, bare metal/network, bootstrap de nodos K8s, incident response. NO: deploys de apps K8s (Helm+ArgoCD), aprovisionamiento cloud (TF), build de imágenes (Dockerfile+Packer). Cruce de frontera: PR requiere ADR + aprobación de plataforma; se mide drift mensualmente.
- **Q11:** Mutable: hosts de larga vida, legacy que no soporta rebuild, cambios frecuentes de config pequeña. Inmutable: nuevos workloads, requisitos de rollback predecible, equipos sin disciplina para Day-2. Deuda del mutable sin disciplina: drift silencioso, imposibilidad de reproducir un estado anterior, snowflake servers.
- **Q12:** Módulos que ejecutan comandos arbitrarios (`shell`, `command`) o que llaman APIs externas sin un "modo simulación" no soportan check: no se puede predecir el efecto. Complemento: entornos de staging idénticos, Molecule por role, `--diff` para los módulos que sí lo soportan, revisión de código.

### Señales de "respondió sin entender"

- Copia la estructura de un playbook de ejemplo pero no adapta `hosts:`, variables, rutas.
- Usa `become: true` a nivel de play "por si acaso" sin tasks que lo requieran.
- "Resuelve" el bug de idempotencia con `changed_when: false` global (hace que todo reporte verde pero oculta cambios reales).
- Confunde `include_role` con `include_tasks` o `import_playbook`.
- Afirma que `ansible-vault` reemplaza a Vault/Secrets Manager "porque también cifra".
- En el ADR, elige Ansible para deploy de app K8s y lo justifica con "mi equipo ya lo conoce".
- `requirements.yml` sin versiones fijadas y afirma que "ansible-galaxy ya maneja compat".

### Preguntas de seguimiento para evaluación en vivo

- "Muéstrame la salida de `ansible-config dump --only-changed`. ¿Qué cambiarías para producción?"
- "Tu playbook de OP-2 corre contra 500 hosts. Un host tiene el dir con dueño incorrecto. ¿Qué pasa y cómo lo verías?"
- "Si borramos el handler `restart app` y simplemente ponemos `service: name=app state=restarted` como task, ¿qué perdemos?"
- "¿Por qué `delegate_to: localhost` + `run_once: true` es un patrón común y qué pasa si solo pones `run_once`?"
- "Si rotamos la password del vault, ¿qué comandos corres y en qué orden? ¿Qué puede romperse en CI?"
- "En tu ADR eliges secret manager externo. Si el secret manager está caído, ¿Ansible debe correr o abortar? Defiende."
- "Molecule con driver docker pasa. ¿Qué puede fallarte en una VM real que el contenedor no reproduce?"
- "¿Cuándo retirarías un playbook y a qué migrarías?"

### Red flags (anulan la respuesta/ejercicio)

Ver `competency-matrix.yaml → red_flags`. Cualquiera observada en el entregable implica: la pregunta/ejercicio donde aparece suma **0**, y se añade una nota al feedback. Dos red flags en el mismo examen suspenden automáticamente (independiente del puntaje).

---

## 6. Composición de la nota y entrega

- Conceptual: suma ponderada de Q1–Q12 (35% del total).
- Operativo: rúbrica aplicada a los artefactos (40% del total).
- Arquitectónico: rúbrica aplicada al ADR (25% del total).
- Umbral: 70%, sin que ningún bloque quede por debajo de 50%.
- Red flags: ver arriba.

**Entrega del estudiante:**

```
exam-submission/
  answers.md                 # respuestas a Q1..Q12
  operative/
    inventory.yml
    good_playbook.yml
    templates/app.conf.j2
    lint-notes.md
    run-transcript.txt       # salida de validate.sh (o justificación SKIP)
  architectural/
    adr-ansible-boundary.md
```
