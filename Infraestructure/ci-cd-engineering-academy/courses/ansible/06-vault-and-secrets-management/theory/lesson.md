# ans-06 — Lección: vault y gestión de secretos

> 10 secciones. Mitad práctica, mitad conceptual. Prerrequisitos: `ans-02`, `sec-02`.

---

## 1. El problema: secretos en el repo

Un playbook típico necesita contraseñas, API keys, tokens de TLS, DSN de bases de datos, claves SSH. La pregunta no es "¿los necesito?" sino "¿**dónde** viven y **quién** los puede leer?". Las malas opciones son:

1. **En plano** dentro de `group_vars/prod.yml`, commiteado a Git → cualquiera con acceso al repo (y a los clones, y a los backups) tiene las creds de prod.
2. **En variables de entorno** del runner → mejor, pero el runner los puede logear, y cambiar un secreto implica tocar la config del runner.
3. **En un paste local no versionado** → el bus factor es 1 y el secreto se pierde cuando el laptop muere.

`ansible-vault` es la respuesta mínima de Ansible al problema: **encripta archivos YAML con AES-256-CTR usando una password simétrica**, y Ansible los desencripta al momento de ejecutar. El archivo encriptado **sí** se commitea; la password **no**.

> **Idea clave:** `ansible-vault` es cifrado simétrico. La password es un secreto más — moviste el problema, no lo eliminaste. Para prod serio, el estado del arte es que Ansible **consulte** un secret manager en tiempo de ejecución (via lookup o módulo), no que el secreto viva encriptado en el repo.

---

## 2. Comandos de `ansible-vault`

Seis comandos, todos operan sobre archivos YAML (o cualquier texto):

| Comando | Qué hace |
|---------|----------|
| `ansible-vault create secrets.yml` | Crea un archivo nuevo encriptado (abre `$EDITOR`). |
| `ansible-vault edit secrets.yml` | Abre el archivo encriptado en `$EDITOR`, lo guarda encriptado al salir. |
| `ansible-vault encrypt secrets.yml` | Encripta **in-place** un archivo que ya existe en claro. |
| `ansible-vault decrypt secrets.yml` | Desencripta **in-place** (vuelve a claro). Peligroso: nunca lo hagas en el working tree sin stash. |
| `ansible-vault view secrets.yml` | Imprime el contenido descifrado por stdout (no toca el archivo). |
| `ansible-vault rekey secrets.yml` | Cambia la password del archivo. Pide la vieja y la nueva. |

El archivo encriptado tiene un header reconocible — ejemplo real tras `encrypt`:

```text
$ANSIBLE_VAULT;1.1;AES256
62313365396662343061393464336163383835346337653064383738373731383466393634356564
3832386366623664333134666662393261623862663437350a393831336266383532323834336631
...
```

La primera línea indica versión del formato (`1.1` o `1.2` para IDs etiquetados) y el cipher (`AES256`).

---

## 3. Encriptar archivo completo vs encriptar un string

Dos modos y dos trade-offs:

**Archivo completo** (`ansible-vault encrypt group_vars/prod.yml`):

- Simple de operar.
- `git diff` sobre un archivo encriptado es ilegible — un cambio de una variable se ve como un cambio total.
- Toda persona que puede leer una sola variable del archivo puede leer **todas**.

**String individual** (`ansible-vault encrypt_string 'super-secret' --name 'db_password'`):

Produce un bloque YAML pegable:

```yaml
db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          37346361316363306531623034323364626234373931616434356233643532323831636562363132
          ...
```

- Puedes mezclar vars en claro y vars encriptadas en el mismo archivo.
- `git diff` sigue siendo legible para el 95% del archivo.
- Más tedioso: cada vez que cambias un valor, re-ejecutas `encrypt_string`.

**Regla práctica:** en `group_vars/all.yml` donde la mayoría son valores públicos y 2–3 son secretos, usa `encrypt_string`. En `group_vars/prod.yml` donde **todo** es sensible, encripta el archivo entero.

---

## 4. Vault password sources

Ansible necesita la password para desencriptar. Opciones:

- `--ask-vault-pass` — Ansible la pide por stdin. Útil manual, imposible en CI.
- `--vault-password-file ~/.vault_pass` — archivo plano con la password. **No commitear**, meter en `.gitignore` global y permisos `0600`.
- `--vault-password-file ./get-pass.sh` — si el archivo es **ejecutable**, Ansible lo corre y lee la password del stdout. Permite llamar a `pass`, `1Password CLI`, `aws secretsmanager get-secret-value`, etc.
- `ANSIBLE_VAULT_PASSWORD_FILE=...` — variable de entorno con la ruta.

En CI, el patrón común es: el runner tiene permisos para leer un secret en AWS Secrets Manager o Vault, un script lo imprime a stdout, y Ansible lo consume. **La password nunca aparece en logs** si el script es correcto.

---

## 5. Múltiples vault IDs

Un repo serio tiene secretos de **dev**, **stg**, **prod**. No quieres que el ingeniero de dev pueda leer prod. Solución: distintas passwords, etiquetadas con **vault IDs**:

```bash
ansible-vault encrypt --vault-id dev@~/.vault/dev_pass group_vars/dev.yml
ansible-vault encrypt --vault-id prod@~/.vault/prod_pass group_vars/prod.yml
```

El archivo encriptado graba el **label** (`dev` o `prod`) en el header (`$ANSIBLE_VAULT;1.2;AES256;prod`). Cuando ejecutas:

```bash
ansible-playbook site.yml \
  --vault-id dev@~/.vault/dev_pass \
  --vault-id prod@~/.vault/prod_pass
```

Ansible intenta cada vault-id contra cada archivo y usa el que matchea el label. Si el ingeniero no tiene `~/.vault/prod_pass`, los archivos de prod **fallan a desencriptar** y el playbook se detiene antes de tocar prod.

> **Práctica real:** el password de prod vive en un secret manager accesible solo a 2 personas y al CI runner de la rama `main`. Los de dev los puede tener cada ingeniero.

---

## 6. `no_log: true` y leaks por stdout

`ansible-vault` protege el **archivo en reposo**. Pero cuando Ansible ejecuta un task y lo imprime en stdout (`-v`, `-vv`), los parámetros aparecen en claro. Un `register:` sobre la respuesta de una API también puede guardar tokens.

Patrón mínimo:

```yaml
- name: Crear usuario con password
  ansible.builtin.user:
    name: app
    password: "{{ app_password | password_hash('sha512') }}"
  no_log: true
```

`no_log: true` suprime el **stdout** del task completo (no verás ni el nombre del módulo ni los args ni el resultado). En debug, cuesta ver qué pasó — por eso solo en tasks que **sí** manejan secretos.

---

## 7. Lookups a secret managers externos

El patrón recomendado para prod es: el secreto vive en **AWS Secrets Manager** / **HashiCorp Vault** / **Azure Key Vault** / **GCP Secret Manager**, y Ansible lo lee en tiempo de ejecución con un lookup. El valor **nunca** toca el repo.

Ejemplo con AWS Secrets Manager (requiere la collection `amazon.aws` y credenciales AWS en el runner):

```yaml
- name: Obtener password de RDS
  ansible.builtin.set_fact:
    rds_password: "{{ lookup('amazon.aws.aws_secret', 'prod/rds/password', region='eu-west-1') }}"
  no_log: true
```

Equivalente con HashiCorp Vault (collection `community.hashi_vault`):

```yaml
- name: Obtener secret desde Vault
  ansible.builtin.set_fact:
    api_token: "{{ lookup('community.hashi_vault.vault_read', 'secret/data/prod/api')['data']['token'] }}"
  no_log: true
```

Ventajas sobre `ansible-vault`:

- **Rotación**: cambiar el secreto en AWS SM lo refleja en el próximo run sin cambiar el repo.
- **Auditoría**: SM registra quién lee qué y cuándo.
- **Autorización fina**: distintos roles IAM leen distintos paths.
- **No hay secret en el repo**, ni encriptado ni en claro.

Contras:

- Requiere conectividad y auth en el runner.
- Añade dependencia operativa (si SM está caído, el deploy también).

---

## 8. SOPS y External Secrets Operator — alternativas vigentes

`ansible-vault` no es la única opción para "secretos encriptados en el repo". Dos competidores vigentes a 2026:

### SOPS (Mozilla)

- Encripta **solo los valores** de un YAML/JSON, dejando las keys en claro → `git diff` legible.
- Usa claves **asimétricas**: AWS KMS, GCP KMS, Azure Key Vault, PGP, age.
- Múltiples recipients por archivo (Alice puede desencriptar con su KMS key, Bob con la suya).
- Rotación de claves vía re-encrypt del archivo.
- Se integra con Terraform, Helm, kustomize, y existe un lookup `community.sops.sops` para Ansible.

Comparado con `ansible-vault`:

| | ansible-vault | SOPS |
|---|---------------|------|
| Cifrado | simétrico (password compartida) | asimétrico (KMS/age/PGP) |
| Diffs | ilegibles (archivo completo) | legibles (solo valores) |
| Rotación | manual (`rekey`) | re-encrypt con nueva key |
| Multi-usuario | 1 password = todos iguales | recipients distintos por archivo |
| Dependencia externa | ninguna | KMS/PGP (cloud o local) |

### External Secrets Operator (K8s)

- **No es** una herramienta de encriptación en repo. Es un operator de Kubernetes que **sincroniza** secretos desde un backend (AWS SM, Vault, GCP SM, Azure KV, 1Password) hacia `Secret` objects nativos de K8s.
- Modelo: declaras un `ExternalSecret` CRD que apunta a un path del secret manager; el operator lo materializa como `Secret` K8s.
- Resuelve el "deploy app en K8s con secretos" sin tocar `ansible-vault` ni montar lookups en el pipeline.
- **No aplica** a Ansible puro (hosts no-K8s). Si tu workload corre en EC2 bare metal, usas lookups desde Ansible.

### Matriz rápida

| Escenario | Herramienta recomendada |
|-----------|-------------------------|
| Playbook pequeño, 1 secreto, 1 equipo | `ansible-vault` (file o `encrypt_string`) |
| Repo compartido, diffs importantes, cloud disponible | SOPS con KMS |
| Deploy serio en EC2/bare-metal con rotación | lookup a AWS SM / Vault |
| App en Kubernetes | External Secrets Operator + backend |

---

## 9. Rotación y auditoría — las preguntas que `ansible-vault` no resuelve

`ansible-vault rekey` cambia la password pero: no hay auditoría de quién leyó qué, no hay versiones, y la password sigue siendo un secreto compartido. Preguntas que debes poder responder antes de usar `ansible-vault` en prod serio:

1. **¿Quién tiene la password?** ¿Dónde está documentado? ¿Qué pasa cuando esa persona se va?
2. **¿Cada cuánto se rota?** ¿Quién lo hace? ¿El proceso está automatizado?
3. **¿Cómo auditas quién leyó el secreto?** (Spoiler: con `ansible-vault` solo, no puedes).
4. **¿Qué pasa si el repo se filtra?** Un atacante tiene el archivo encriptado y tiempo. AES-256 aguanta hoy, ¿aguantará en 10 años?
5. **¿Diferencias prod vs dev?** Si usas una sola password para los dos, un dev con acceso al repo tiene las creds de prod.

Si **cualquiera** de estas preguntas no tiene respuesta cómoda, estás pidiendo migrar a secret manager externo.

---

## 10. Resumen operativo

- `ansible-vault` encripta YAMLs con AES-256. Vive en el repo. La password **no**.
- Prefiere `encrypt_string` para archivos mixtos; `encrypt` para archivos íntegramente secretos.
- Usa `--vault-id dev@... --vault-id prod@...` para separar scopes.
- `no_log: true` protege los **logs**, no los archivos.
- En CI, la vault password viene de un secret manager vía script ejecutable.
- Para prod serio, salta al **lookup directo** desde AWS SM / Vault / etc.
- **SOPS** es la alternativa buena cuando quieres diffs legibles y cifrado asimétrico.
- **External Secrets Operator** resuelve el problema en K8s, no en Ansible puro.
- Nunca commitees secretos reales en los ejemplos: usa `fake-password-not-real`.
