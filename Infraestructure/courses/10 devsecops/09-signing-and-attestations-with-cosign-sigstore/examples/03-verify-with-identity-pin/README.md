# Ejemplo 03 — Verificación segura con pin de identidad (walkthrough)

> **Walkthrough.** Diseccionamos tres verificaciones: dos inseguras, una correcta. El objetivo es que cuando leas una PR con `cosign verify ...` reconozcas al vuelo si la verificación **vale** o **es un adorno**.

## 1. Caso A — Insegura (acepta cualquier firma de Fulcio)

```bash
cosign verify ghcr.io/acme/payments:v1
```

**Qué comprueba realmente:**

- Que exista una firma adjunta.
- Que la firma la haya emitido *alguna* identidad válida para la raíz de Sigstore.

**Qué NO comprueba:**

- Quién firmó. Cualquier identidad OIDC que haya pasado por Fulcio pasa.
- Un atacante que publique una imagen en su propio registry y la firme desde su propio repo público → firma válida.

**Veredicto:** inútil como control de seguridad. Equivalente a `curl --insecure` creyendo que verifica TLS.

## 2. Caso B — Insegura (fija issuer pero no identidad)

```bash
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/acme/payments:v1
```

**Qué suma al caso A:**

- Restringe a firmas emitidas en GitHub Actions.

**Qué sigue sin comprobar:**

- Qué repo. Cualquier repo en GitHub Actions puede firmar y pasar.

**Veredicto:** aún insuficiente. Un repo público creado por el atacante firma algo y la verificación pasa.

## 3. Caso C — Segura (issuer + identidad fijada por regex con tag)

```bash
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/payments/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
  ghcr.io/acme/payments:v1.2.3
```

**Qué garantiza:**

- Firma emitida por GitHub Actions.
- En el repo `acme/payments`.
- Por el workflow `release.yml`.
- Disparado por un **tag** con forma `vMAJOR.MINOR.PATCH`.

**Por qué el pin es por tag y no por branch:** un atacante con write a `main` podría ejecutar `release.yml` desde `main` y firmar algo. Fijar por tag deja la línea de defensa en "¿quién puede crear tags firmados y empujarlos?" — que debería estar protegido por ruleset / branch protection del repo.

## 4. Cómo falla cada caso ante los mismos ataques

| Ataque                                                | Caso A | Caso B | Caso C |
|-------------------------------------------------------|:------:|:------:|:------:|
| Atacante firma desde un repo propio                   |  pasa  |  pasa  |  **falla** |
| Atacante consigue write a `main` del repo víctima     |  pasa  |  pasa  |  **falla** (si el pin es por tag) |
| Imagen sin firma                                      | falla  | falla  | falla  |
| Imagen firmada por la identidad esperada              |  pasa  |  pasa  |  pasa  |

## 5. Resumen operativo

- **Nunca** aceptes `cosign verify` sin `--certificate-identity[-regexp]` y `--certificate-oidc-issuer`.
- **Pinea por tag/release**, no por branch de desarrollo.
- Si usas `--certificate-identity-regexp`, **ancla con `^` y `$`** — un regex sin anclas abre un universo de falsos positivos.
- Toda política documentada debe incluir *el comando exacto* que el consumidor debe correr. La ausencia de ese comando convierte la política en folklore.
