# Ejemplo 03 — EDA (webhook) + walkthrough AWX/AAP

> Lectura y análisis. Sin ejecución. Objetivo: ver cómo encaja Event-Driven Ansible (EDA) con un webhook, y recorrer la UI de AWX/AAP (Project → Inventory → Credential → Job Template → Workflow → Survey → Notification → Schedule).

## 1. EDA — anatomía de un rulebook

Un **rulebook** declara una o más fuentes de eventos, condiciones y acciones. Formato similar a un playbook pero con otra gramática: `sources` + `rules`.

`rulebook.yml`:

```yaml
---
- name: Restart web on webhook signal
  hosts: all
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Trigger restart playbook
      condition: event.payload.action == "restart_web"
      action:
        run_playbook:
          name: playbooks/restart_web.yml
          extra_vars:
            target: "{{ event.payload.target | default('role_web') }}"
```

- `sources` — plugin `ansible.eda.webhook` levanta un HTTP listener en el puerto 5000.
- `rules` — "si el payload trae `action: restart_web`, lanza el playbook".
- `action.run_playbook.extra_vars` — pasa variables al playbook (aquí, el grupo de hosts a reiniciar).

Lanzar:

```bash
ansible-rulebook --rulebook rulebook.yml -i inventory.yml
```

Simular un evento:

```bash
curl -X POST http://localhost:5000/endpoint \
  -H 'Content-Type: application/json' \
  -d '{"action":"restart_web","target":"role_web_prod"}'
```

El rulebook recibe el POST, evalúa la condición, dispara `playbooks/restart_web.yml`.

## 2. Otras fuentes de eventos útiles

| Plugin | Fuente | Caso típico |
|--------|--------|-------------|
| `ansible.eda.webhook` | HTTP POST | GitHub webhook, Alertmanager webhook, scripts internos |
| `ansible.eda.kafka` | Topic Kafka | Bus de eventos corporativo (CloudTrail → Kafka → EDA) |
| `ansible.eda.alertmanager` | Prometheus Alertmanager | Alerta → auto-remediación |
| `ansible.eda.file` | Archivo plano | Útil para testing / escenarios airgapped |
| `ansible.eda.journald` | journald | Reaccionar a eventos del SO (fallo de servicio) |

## 3. Patrón: alerta → remediación

Flujo clásico:

```
Prometheus detecta "disk > 90% on web-03"
    ↓
Alertmanager envía webhook a EDA
    ↓
Rulebook ve payload { alert: HighDiskUsage, host: web-03 }
    ↓
Dispara playbook cleanup_logs.yml --limit web-03
    ↓
Si éxito: Alertmanager silence por 1h + notifica Slack
Si fallo: notifica on-call Slack + crea ticket
```

El valor: el on-call no recibe la alerta de las 03:00 — se despierta solo si la remediación falló.

**Riesgos** (importantes):

- Un rulebook mal escrito que remedia en el **host equivocado** puede causar más daño que la alerta.
- Un atacante que puede inyectar eventos (webhook sin auth) puede lanzar playbooks arbitrarios. **Siempre** autenticar el webhook (token / mTLS / HMAC).
- Loops: si el playbook deja al host en estado que **vuelve a disparar** la alerta → bucle infinito. Añadir *rate limiting* en el rulebook.

---

## 4. AWX / AAP — walkthrough de la UI

> Nota: AWX es OSS, AAP es la versión Red Hat con soporte. La UI es prácticamente la misma. Capturas no incluidas (varían por versión). Lectura descriptiva.

### 4.1 Project

Un **Project** apunta a un repo Git (con playbooks, roles, rulebooks, inventory plugins, requirements). AWX hace `git pull` periódicamente o on-demand.

Campos:

- **Source Control Type**: Git / SVN / Insights / Manual.
- **Source Control URL**: `git@github.com:org/ansible-platform.git`.
- **Source Control Branch**: `main`.
- **Credential**: SSH key o PAT para clonar.
- **Update options**: `clean`, `update on launch`.

### 4.2 Inventory

Un **Inventory** es la lista de hosts. Puede ser:

- **Static**: hosts hardcoded.
- **Smart**: query sobre otros inventarios.
- **Dynamic**: *inventory source* desde un plugin (AWS, GCP, Azure) o un script.

Para dinámico AWS, el flujo es:

1. Crear **Credential** tipo *Amazon Web Services* con access key / IAM role.
2. Añadir **Inventory Source** al inventario: *Source: Amazon EC2*, apuntando a la credential, con el YAML del inventory plugin.
3. Scheduler: refrescar cada N minutos.

### 4.3 Credential

Un **Credential** encapsula un secreto (SSH key, cloud API key, vault password, token). Hay tipos predefinidos (Machine, Vault, AWS, GCP, Red Hat Satellite, HashiVault, etc.) y puedes crear *credential types* custom.

Clave: los secretos **nunca** se pueden "leer" desde la UI tras guardarse. Solo se usan. Esto es parte del valor de AWX sobre `ansible-playbook` desde una laptop.

### 4.4 Job Template

Un **Job Template** encapsula una ejecución reproducible:

- **Inventory**: cuál (del catálogo).
- **Project**: cuál (del catálogo).
- **Playbook**: ruta dentro del project (`playbooks/site.yml`).
- **Credentials**: SSH + vault + cloud (puedes atar varias).
- **Variables / Survey**: extra-vars fijos y/o encuesta.
- **Verbosity, Forks, Limit, Tags**: flags habituales.
- **Options**: *Enable concurrent jobs*, *Enable fact storage*, *Prevent instance group fallback*.

Lanzar: botón **Launch**. AWX pre-rellena si hay survey y pide los campos.

### 4.5 Survey

Una **Survey** es un formulario adjunto a un job template. Campos: text, textarea, password, multiplechoice, multiselect, integer, float. Cada respuesta se convierte en un extra-var del playbook.

Ejemplo: survey del template "Deploy to env" con `env` (choices: dev/stg/prod), `version` (text). El playbook recibe `-e env=prod -e version=1.2.3`.

Esto permite que un operador de soporte lance despliegues sin tocar YAML.

### 4.6 Workflow Template

Encadena N job templates con lógica:

```
[Build AMI] -(on success)-> [Terraform apply]
                   \-(on failure)-> [Notify oncall]
          [Terraform apply] -(on success)-> [Ansible converge]
                                   \-(on failure)-> [Rollback]
```

Workflow templates también soportan **approval nodes**: el workflow se para y espera que un humano apruebe en la UI antes de continuar (útil para prod).

### 4.7 Notification

Attach a job templates o workflow templates. Tipos: Email, Slack, Webhook, Mattermost, Grafana, PagerDuty, RocketChat, Twilio. Dispara on *success / failure / started*.

### 4.8 Schedule

Cron en la UI. Útil para:

- Patching semanal.
- Compliance scan nocturno.
- Housekeeping (rotación de logs, limpieza de artefactos).

### 4.9 RBAC

Roles predefinidos: *Admin*, *Execute*, *Project Admin*, *Inventory Admin*, *Credential Admin*, *Read*, etc. Se asignan a **Teams** y **Users** por objeto (job template, inventory, credential…).

Ejemplo: team *Soporte* tiene *Execute* sobre el job template "Restart web prod" + *Read* sobre el inventario `prod/web`. No puede ver credenciales ni editar playbooks.

---

## 5. ¿AWX/AAP vale el coste?

| Situación | Veredicto |
|-----------|-----------|
| 1 equipo DevOps de 3 personas, 2 playbooks, corren desde CI | **No**. `ansible-playbook` + Vault + CI basta. |
| 20+ personas de equipos distintos corren Ansible | **Sí**. RBAC + credentials centralizadas pagan solas. |
| Requisito regulatorio de audit log de quién corrió qué | **Sí**. AAP tiene esto nativo. |
| Soporte / NOC necesita lanzar runbooks sin tocar YAML | **Sí**. Surveys lo hacen trivial. |
| Todo en Kubernetes | **No** si solo es K8s. GitOps resuelve mejor. |
| Mix on-prem + cloud + network + K8s | **Sí** (al menos AWX). Es el caso donde más brilla. |

---

## 6. Preguntas de autocomprobación

1. ¿Qué pasa si el webhook de EDA no está autenticado y el puerto 5000 es público?
2. ¿Diferencia entre un *Project* y un *Playbook* en AWX?
3. ¿Por qué los secretos en AWX no se pueden leer después de guardarse?
4. ¿Cuándo usarías *approval node* en un workflow?
5. ¿Qué tres cosas aporta un Job Template sobre `ansible-playbook` desde la terminal?
