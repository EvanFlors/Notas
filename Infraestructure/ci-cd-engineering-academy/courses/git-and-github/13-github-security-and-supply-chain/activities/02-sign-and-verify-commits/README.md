# Actividad 02 — Firmar y verificar commits con SSH

## 1. Identificación

- **ID:** `gh-13-02-sign-and-verify-commits`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-13-github-security-and-supply-chain`
- **Dificultad:** intermediate
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab (100% local, sin GitHub)

## 2. Contexto

El badge **Verified** de GitHub requiere firma criptográfica. Lo mismo pueden exigir rulesets productivos (`required_signatures`). Esta actividad te lleva por el camino **SSH signing** completo: generar una clave dedicada a firmar, configurar git, preparar el `allowed_signers` para que `git verify-commit` tenga a quién atribuir, hacer commits firmados y verificarlos **por dos vías independientes**.

Es 100% local: no necesitas cuenta de GitHub ni red. La validación comprueba las firmas directamente.

## 3. Objetivos

- Generar una clave SSH **exclusiva para firmar** (buena práctica: separada de la de auth).
- Configurar git: `gpg.format=ssh`, `commit.gpgsign=true`, `user.signingkey`, `gpg.ssh.allowedSignersFile`.
- Crear un `allowed_signers` correcto para que la verificación atribuya la firma a tu identidad.
- Producir **al menos 2 commits firmados** en la rama `main`.
- Verificar con `git log --show-signature` y con `ssh-keygen -Y verify` crudo.

## 4. Prerrequisitos

- Git ≥ 2.34 (`git --version`).
- OpenSSH ≥ 8.0 (`ssh -V`).
- Haber leído `theory/lesson.md` secciones 2.2, 2.3, 4.1 y 5.
- Haber reproducido `examples/01-sign-commits-with-ssh/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/sign-and-verify
```

Esto crea `/tmp/sign-and-verify/` con un repo vacío inicializado en `main` y un `README.md` recordando la tarea. **No** crea claves ni toca configuración de firma — eso lo haces tú.

### 5.2 Tareas

Trabaja dentro de `/tmp/sign-and-verify/repo` (o usa `--git-dir` si prefieres):

1. **Generar la clave de firma** en `/tmp/sign-and-verify/keys/signing_ed25519` (ed25519, sin passphrase para la demo).
2. **Configurar el repo** (configuración local — NO global, para no ensuciar tu máquina):
   - `user.name` = algo identificable, p. ej. `Student`.
   - `user.email` = p. ej. `student@example.com`.
   - `gpg.format` = `ssh`.
   - `user.signingkey` = ruta absoluta a la **pública** `.pub`.
   - `commit.gpgsign` = `true`.
   - `tag.gpgsign` = `true` (opcional pero recomendado).
   - `gpg.ssh.allowedSignersFile` = ruta a `/tmp/sign-and-verify/config/allowed_signers`.
3. **Crear `allowed_signers`** con una línea de formato `<email> <contenido de la pública>`.
4. **Hacer al menos 2 commits** firmados en `main` (p. ej. añadir `README.md` y un `app.sh`).
5. **Verificar**:
   - `git log --show-signature -1` debe decir `Good "<tu-email>" signature with ED25519 key …`.
   - Opcional: `git verify-commit HEAD` termina con exit 0.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/sign-and-verify
```

El validator comprueba:
- Que la clave `signing_ed25519` existe en `/tmp/sign-and-verify/keys/`.
- Que el repo existe y la configuración `gpg.format`, `commit.gpgsign`, `user.signingkey`, `gpg.ssh.allowedSignersFile` está correcta.
- Que `allowed_signers` existe y tiene la pública con el email configurado.
- Que al menos 2 commits en `main` tienen firma SSH válida (verificando con `ssh-keygen -Y verify` directamente, sin depender de git).

### 5.4 Pistas

- Pista 1: `ssh-keygen -t ed25519 -N ""` (sin passphrase).
- Pista 2: `git config commit.gpgsign true` (dentro del repo, no `--global`).
- Pista 3: El `allowed_signers` tiene una línea por identidad: `email ssh-ed25519 AAAA… comment`.
- Pista 4: Para verificar manualmente una firma, extrae el commit con `git cat-file commit HEAD`, aísla la parte firmada vs. la firma, y usa `ssh-keygen -Y verify -f allowed_signers -I <email> -n git -s <sig> < <datos>`. Es laborioso; para la actividad basta con `git log --show-signature`.

## 6. Resultado esperado

- `git log --show-signature main` imprime líneas `Good "..." signature` para los commits creados.
- `tests/validate.sh` termina con `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] Clave `signing_ed25519` + `.pub` presentes en `/tmp/sign-and-verify/keys/`.
- [ ] Configuración git correcta (6 keys bien).
- [ ] `allowed_signers` bien formado.
- [ ] ≥ 2 commits firmados y verificables en `main`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sign-and-verify
```

Reporte por check con `OK`/`FAIL` y diagnóstico específico.

## 9. Preguntas de reflexión

1. ¿Qué pasa si cambias el campo `author` del último commit (vía `git commit --amend --author='Alguien <otro@x.com>'`)? ¿La firma sigue siendo válida? ¿Por qué?
2. ¿Por qué conviene **separar** la clave de firma de la de autenticación SSH?
3. Si subes la pública a GitHub como **Authentication Key** y no como **Signing Key**, ¿tu commit aparecerá como "Verified"? ¿Por qué?
4. En un equipo de 30 personas, ¿cómo distribuyes y mantienes el `allowed_signers`? ¿Y la revocación cuando alguien deja el equipo?
5. ¿Qué garantiza y qué NO garantiza una firma de commit?

## 10. Extensiones

- **E1** — Firma un tag (`git tag -s v0.1.0 -m 'firmado'`) y verifícalo con `git tag -v`.
- **E2** — Rota tu clave: genera una nueva, actualiza `allowed_signers` para aceptar ambas (línea doble), haz un commit con la nueva. Documenta cómo lo harías en un equipo real.
- **E3** — Investiga `gitsign` (Sigstore) y reproduce el mismo flujo keyless si tienes un IdP OIDC disponible.

## 11. Limpieza

```bash
rm -rf /tmp/sign-and-verify
```

Si configuraste algo `--global` por error, revisa `~/.gitconfig` y revierte lo que no quieras persistir.
