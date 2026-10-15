# Actividad 01 — Enable secret scanning + push protection (dual-mode)

## 1. Identificación

- **ID:** `gh-13-01-enable-secret-scanning-and-push-protection`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-13-github-security-and-supply-chain`
- **Dificultad:** intermediate
- **Duración estimada:** 40–55 min
- **Tipo:** guided-lab (dual-mode: live GitHub o local)

## 2. Contexto

Secret scanning + push protection es el control **del servidor** que atrapa secretos en el repo. Un hook pre-commit local (gitleaks, trufflehog, o uno hecho a mano) es el control **del cliente** que los atrapa antes.

En producción se usan los **dos** (defensa en profundidad). Esta actividad te hace configurar **al menos uno**, con el otro documentado.

## 3. Objetivos

- (MODE=live) Habilitar secret scanning y push protection en un repo GitHub de prueba, por API o UI.
- (MODE=local) Configurar un hook pre-commit que bloquee patrones comunes de secretos (AWS, GitHub tokens, Stripe, etc.).
- Añadir un `SECURITY.md` que documente el modelo de seguridad y el canal PVR.
- Verificar operacionalmente que **un commit con un secreto es bloqueado**.

## 4. Prerrequisitos

- `git` instalado.
- Para MODE=live: cuenta de GitHub con permiso para crear/modificar un repo, `gh` CLI autenticada.
- Para MODE=local (recomendado para la actividad): nada más.

**Costos**: USD 0 en ambos modos. En GitHub, secret scanning es gratis para repos públicos; en privados requiere Advanced Security (del plan Enterprise o add-on).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/sec-scanning
```

Esto crea `/tmp/sec-scanning/repo` con un repo vacío y un `SECURITY.md` sin terminar.

### 5.2 Tareas (MODE=local — por defecto)

Trabaja en `/tmp/sec-scanning/repo`:

1. **Escribir un hook `pre-commit`** en `.git/hooks/pre-commit` (ejecutable) que **bloquee el commit** si el diff staged contiene cualquiera de los siguientes patrones:
   - `AKIA[0-9A-Z]{16}` (AWS Access Key ID)
   - `ghp_[0-9A-Za-z]{36}` (GitHub Personal Access Token classic)
   - `sk_live_[0-9A-Za-z]{10,}` (Stripe live secret key)
   - `-----BEGIN( RSA| OPENSSH| EC| DSA)? PRIVATE KEY-----` (claves privadas)

   Debe:
   - Imprimir qué patrón y qué archivo encontró.
   - Exit con código ≠ 0 para abortar el commit.
   - **No** usar binarios externos (debe funcionar en un Mac/Linux limpio solo con bash + git + grep).

2. **Completar `SECURITY.md`** con las secciones:
   - **Reporting**: cómo reportar vulnerabilidades (vía PVR en GitHub).
   - **Controls**: lista de controles activos (secret scanning server-side + hook local; firma de commits; Dependabot; OIDC; etc.).
   - **Rotation**: política de rotación.

3. **Verificar manualmente** que un intento de commit con un secreto se bloquea:
   ```bash
   echo 'export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE' > fake.env
   git add fake.env
   git commit -m "oops"   # debe FALLAR
   git restore --staged fake.env && rm fake.env
   ```

### 5.3 Tareas (MODE=live — opcional)

Si prefieres probar la vía servidor en un repo real:

```bash
gh api -X PATCH /repos/OWNER/REPO \
  -f security_and_analysis.secret_scanning.status=enabled \
  -f security_and_analysis.secret_scanning_push_protection.status=enabled
```

- Haz el commit del test con un AWS Access Key dummy (`AKIAIOSFODNN7EXAMPLE`) y pushea. Deberías ver **push rejected**.
- Documenta en `SECURITY.md` que el servidor valida.
- La validación automatizada aún se corre con `MODE=local` por defecto. Si quieres que el validator **omita** el check del hook local porque confías en el servidor, define `MODE=live` y el test cambiará su veredicto para esa parte (sigue requiriendo `SECURITY.md`).

### 5.4 Validar

```bash
# MODE=local (default)
bash tests/validate.sh /tmp/sec-scanning

# MODE=live
MODE=live bash tests/validate.sh /tmp/sec-scanning
```

### 5.5 Pistas

- Pista 1: Para iterar sobre los archivos staged: `git diff --cached --name-only --diff-filter=ACMRT`.
- Pista 2: Para obtener el contenido staged de un archivo: `git show ":<path>"`.
- Pista 3: Define los patrones en un array y recórrelos con `grep -E`.
- Pista 4: No olvides `chmod +x .git/hooks/pre-commit`.

## 6. Resultado esperado

- Hook pre-commit presente, ejecutable y funcional.
- Un commit con un secreto de prueba es **rechazado** por el hook.
- `SECURITY.md` con las 3 secciones completas.
- `tests/validate.sh` → `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] `.git/hooks/pre-commit` existe y es ejecutable.
- [ ] El hook detecta y bloquea los 4 patrones mínimos listados.
- [ ] `SECURITY.md` tiene las secciones Reporting / Controls / Rotation con contenido no trivial.
- [ ] En MODE=live: documentado el uso del API (`security_and_analysis`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-scanning
```

El validator realiza en MODE=local:

1. Verifica que el repo existe.
2. Verifica que `.git/hooks/pre-commit` existe y es ejecutable.
3. **Simula** un commit con un `AKIA...` y confirma que es rechazado (exit ≠ 0 del commit).
4. Verifica que `SECURITY.md` existe y contiene las 3 secciones (headers `Reporting`, `Controls`, `Rotation`).

## 9. Preguntas de reflexión

1. ¿Por qué un hook pre-commit **no basta** como control único? Da 2 escenarios en que falla.
2. ¿Qué diferencia operacional hay entre que GitHub **rechace el push** vs. que **abra una alerta tras el push**? ¿Cuál prefieres para `main` y por qué?
3. Un dev hace `git commit --no-verify`. ¿Qué controles del lado servidor atrapan esto?
4. En MODE=live, imagina que la push protection bloquea un dev y éste pide bypass con "es un string de ejemplo, no un secreto real". ¿Qué política defines para aprobar/denegar bypass?
5. ¿Qué secretos son los *más* difíciles de detectar por patrón? ¿Qué estrategia complementaria usarías?

## 10. Extensiones

- **E1** — Reemplaza tu hook casero por `gitleaks` (`.pre-commit-config.yaml` + framework `pre-commit`).
- **E2** — Añade al hook un patrón custom para una API interna de tu organización (p. ej. `MYORG_TOKEN_[A-Z0-9]{40}`).
- **E3** — Habilita el workflow de CodeQL en el repo (requiere GitHub) y documenta cómo se integra con el ruleset de `main`.

## 11. Limpieza

```bash
rm -rf /tmp/sec-scanning
```

En MODE=live, si creaste un repo de prueba, archívalo o elimínalo:

```bash
gh repo delete OWNER/REPO --yes
```
