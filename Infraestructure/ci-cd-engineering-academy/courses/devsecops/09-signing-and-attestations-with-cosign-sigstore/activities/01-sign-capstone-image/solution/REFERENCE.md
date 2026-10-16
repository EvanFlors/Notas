# REFERENCE — sec-09-01-sign-capstone-image

> Modelo razonado. No es la única respuesta correcta.

## Qué debería haber producido `run.sh`

- Un `registry:2` escuchando en `localhost:5000` (contenedor `sec09-registry`).
- Una imagen `localhost:5000/sec09/payments:v1` con digest estable.
- `IMAGE_DIGEST` = `sha256:<64 hex>`.
- Dos pares de claves cosign: `cosign.{key,pub}` y `wrong.{key,pub}`.
- Verificación positiva con `cosign.pub` → exit 0.
- Verificación negativa con `wrong.pub` → exit != 0.

## SIGN-LOG.md — modelo (7 líneas)

```markdown
# Firma key-based — qué garantiza y qué no

- Integridad: cualquier modificación de las capas invalida la firma (hash del digest).
- Autenticidad respecto a la pub key: solo quien tenga la priv key correspondiente puede
  haber producido esta firma. Verifica contra `cosign.pub` (la "otra" clave `wrong.pub`
  falla, como debe).
- NO garantiza no-repudio: no hay log público tipo Rekor. El firmante puede negar
  la firma (o retirarla) sin que haya rastro externo.
- NO vincula a una identidad humana ni a un workflow concreto: la "identidad" es el
  dueño de la priv key, que es un fichero. Si se filtra, se puede forjar firmas
  indistinguibles.
- Mejora inmediata para producción: migrar a keyless con Fulcio+Rekor y verificar
  con `--certificate-identity` + `--certificate-oidc-issuer`.
```

## Errores comunes

- Firmar por tag (`:v1`) en lugar de por digest (`@sha256:...`): la firma queda
  "flotante" y una repush al mismo tag deja huérfana la firma vieja.
- Olvidar `--allow-insecure-registry` para `localhost:5000` sin TLS → cosign se niega.
- No desactivar el tlog (`--insecure-ignore-tlog=true` en verify, o `--tlog-upload=false`
  en sign) cuando no hay acceso a Rekor público: cosign intenta subir y falla.
- Reusar las mismas claves entre actividades/entornos — en producción, cada entorno
  debe tener su propio material criptográfico.

## Qué viene después (actividad 02)

Diseñar la **política de verificación** que un consumidor en entorno limpio aplicaría
sobre una imagen firmada **keyless** (no sobre esta prueba académica con claves).
