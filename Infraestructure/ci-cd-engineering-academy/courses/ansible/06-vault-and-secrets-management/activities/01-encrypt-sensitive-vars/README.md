# Actividad 01 — Encriptar variables sensibles con `ansible-vault`

## 1. Identificación

- **ID:** `ans-06-01-encrypt-sensitive-vars`
- **Tecnología:** `ansible`
- **Módulo:** `ans-06-vault-and-secrets-management`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab (práctico, pasos guiados)

## 2. Contexto

Tienes un repo Ansible con dos entornos (`dev` y `prod`) y un `group_vars/` donde conviven variables públicas (nombre de la app, puerto) y variables sensibles (password de BD, token API). Tu tarea: dejar el repo en un estado seguro para commitear.

**Importante — ningún secreto es real.** Todos los valores son del tipo `fake-password-not-real`. Si en un entorno real reutilizas estos pasos, **nunca** pongas secretos reales en los archivos del repo del curso.

## 3. Objetivos

- Encriptar `group_vars/prod.yml` entero con **vault ID `prod@...`**.
- Encriptar un string individual en `group_vars/all.yml` con `encrypt_string`.
- Verificar que el header del archivo encriptado contiene `$ANSIBLE_VAULT`.
- Verificar con `ansible-vault view` que puedes descifrar con la password correcta.
- Verificar que **sin** la password de prod, `view` falla.
- Documentar en `README-INTENT.md` qué protege cada vault ID.

## 4. Prerrequisitos

- `ansible-core` instalado (`ansible-vault --version` ≥ 2.14).
  - macOS con `pip --user`: `export PATH="$HOME/Library/Python/3.10/bin:$PATH"`.
  - Alternativa: `pipx install ansible-core`.
- Un shell POSIX (`bash` o `zsh`).

**Costos**: ninguno — todo es local, sin red.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-06-vault/{group_vars,.vault}
cd /tmp/ans-06-vault
```

### 5.2 Crear dos passwords de vault (fake)

```bash
echo 'fake-dev-vault-pass'  > .vault/dev_pass
echo 'fake-prod-vault-pass' > .vault/prod_pass
chmod 0600 .vault/*
```

### 5.3 Crear los archivos de variables en claro

`group_vars/all.yml` mezcla claro + encriptado. `group_vars/prod.yml` es íntegramente sensible.

```bash
cat > group_vars/all.yml <<'YAML'
app_name: fastapi-demo
app_port: 8000
# db_password se agregara abajo via encrypt_string
YAML

cat > group_vars/prod.yml <<'YAML'
env: prod
api_token: fake-prod-token-not-real
rds_master_password: fake-rds-password-not-real
YAML
```

### 5.4 Encriptar `group_vars/prod.yml` entero con vault ID `prod`

```bash
ansible-vault encrypt --vault-id prod@.vault/prod_pass group_vars/prod.yml
```

Comprueba el header:

```bash
head -1 group_vars/prod.yml
# Debe mostrar: $ANSIBLE_VAULT;1.2;AES256;prod
```

### 5.5 Encriptar un string individual y pegarlo en `all.yml`

```bash
ansible-vault encrypt_string \
  --vault-id dev@.vault/dev_pass \
  'fake-db-password-not-real' \
  --name 'db_password' >> group_vars/all.yml
```

Verifica el bloque `!vault |` en `group_vars/all.yml`:

```bash
grep -c '!vault' group_vars/all.yml   # debe ser >=1
```

### 5.6 Verificar que puedes descifrar `prod.yml` con la password correcta

```bash
ansible-vault view --vault-id prod@.vault/prod_pass group_vars/prod.yml
```

Debes ver el contenido en claro (`env: prod`, etc).

### 5.7 Verificar que **no** puedes descifrar prod con la password de dev

```bash
set +e
ansible-vault view --vault-id dev@.vault/dev_pass group_vars/prod.yml
rc=$?
set -e
echo "exit code esperado != 0: $rc"
```

Esto **debe** fallar — es el comportamiento deseado.

### 5.8 Escribir `README-INTENT.md`

Documenta la intención del esquema de vault IDs. **Secciones obligatorias** (el validador las busca):

- `# Vault layout`
- `## dev vault`
- `## prod vault`
- `## Rotation plan`

Contenido mínimo obligatorio (el validador también lo exige):

- Mención de `group_vars/prod.yml` y `group_vars/all.yml`.
- Mención de los vault IDs `dev` y `prod`.
- Mención de `fake-password-not-real` o `fake-...` dejando claro que no son secretos reales.
- Mención de la **rotación** (`rekey`) y del principio de que la vault password **no se commitea**.

### 5.9 Entregables en `/tmp/ans-06-vault`

- `group_vars/prod.yml` encriptado con vault ID `prod`.
- `group_vars/all.yml` con un bloque `!vault |` (encrypt_string con vault ID `dev`).
- `.vault/dev_pass` y `.vault/prod_pass` (passwords fake, 0600).
- `README-INTENT.md` con las 4 secciones y el contenido mínimo.

## 6. Resultado esperado

- `head -1 group_vars/prod.yml` → `$ANSIBLE_VAULT;1.2;AES256;prod`
- `grep -c '!vault' group_vars/all.yml` → `≥ 1`
- `ansible-vault view` con la password correcta descifra sin error.
- `ansible-vault view` con la password incorrecta devuelve exit code `≠ 0`.
- El validador en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Seguridad**: ningún secreto real; `.vault/*` tienen permisos `0600`.
- **Reproducibilidad**: puedes volver a correr los pasos y llegar al mismo estado.
- **Mantenibilidad**: `README-INTENT.md` explica el porqué, no solo el qué.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-06-vault
```

El validador comprueba:

1. Que `group_vars/prod.yml` empieza con `$ANSIBLE_VAULT`.
2. Que el header incluye el label `prod`.
3. Que `group_vars/all.yml` tiene al menos un bloque `!vault |`.
4. Que `ansible-vault view --vault-id prod@...` descifra `prod.yml` sin error.
5. Que `ansible-vault view --vault-id dev@...` sobre `prod.yml` **falla**.
6. Que `README-INTENT.md` tiene las 4 secciones y el contenido mínimo.
7. Que no hay strings sospechosos de secretos reales (busca `password:` seguido de valores no `fake-*`).

## 9. Preguntas de reflexión

1. ¿Por qué `encrypt_string` para un único valor es preferible en `group_vars/all.yml` pero `encrypt` entero es mejor en `group_vars/prod.yml`?
2. Si pierdes `.vault/prod_pass`, ¿puedes recuperar `group_vars/prod.yml`? ¿Qué cambia esto respecto a un secret manager externo?
3. En CI, ¿cómo le entregas `.vault/prod_pass` al runner sin commitearla?
4. ¿Qué le pasa al diff de `git` cada vez que cambias una sola variable dentro de `prod.yml` encriptado completo? ¿Y con SOPS?

## 10. Extensiones

- Rota la password de dev con `ansible-vault rekey --vault-id dev@... --new-vault-id dev@...`.
- Añade `no_log: true` a un task que use `rds_master_password` y verifica que el stdout del `ansible-playbook` **no** lo muestra.
- Escribe un script `.vault/prod_pass.sh` que lea la password de un secret manager (puede ser `echo fake-prod-vault-pass` en el ejercicio) y úsalo como `--vault-id prod@.vault/prod_pass.sh` con permisos `0700`.

## 11. Limpieza

```bash
rm -rf /tmp/ans-06-vault
```
