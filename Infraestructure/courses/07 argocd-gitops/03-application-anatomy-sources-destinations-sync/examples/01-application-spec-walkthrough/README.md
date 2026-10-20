# Ejemplo 01 — Walkthrough del `spec.Application`

## Concepto que demuestra

Leer un manifiesto `Application` real campo a campo, comprobando que es sintácticamente válido y entendiendo el efecto de cada bloque.

## Contexto

Antes de escribir uno desde cero (actividad 01), es útil tener un ejemplar "canónico" bien comentado como referencia.

## Prerrequisitos

- `kubectl` instalado (para validación client-side; no requiere cluster).
- Opcional: `kind` + Argo CD del módulo `argo-02` (para validación server-side con `--dry-run=server`).
- Opcional: `kubeconform` para validar contra el schema CRD.

## Archivos

- `application.yaml` — manifiesto `Application` completo con comentarios inline por campo.
- `walkthrough.sh` — script que valida el manifiesto y lo imprime bloque a bloque. Degrada con elegancia si no hay cluster.

## Ejecución

```bash
cd courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/examples/01-application-spec-walkthrough
bash walkthrough.sh
```

Lee el manifiesto a la par que el script lo explica.

## Resultado esperado

- `walkthrough.sh` imprime cada bloque del `spec` con su explicación.
- Validación client-side (`kubectl apply --dry-run=client -f application.yaml`) devuelve OK.
- Si hay cluster con el CRD de Argo CD instalado, validación server-side también OK.
- Si no hay nada, el script lo dice y continúa con la validación offline únicamente.

## Interpretación

- `kubectl --dry-run=client` solo verifica sintaxis YAML y nombres de campos conocidos. No sabe si `argoproj.io/v1alpha1` existe en el cluster.
- `kubectl --dry-run=server` sí lo verifica — por eso requiere Argo CD instalado.
- `kubeconform` puede validar contra un schema remoto del CRD sin cluster. Ver <https://github.com/yannh/kubeconform>.

## Errores frecuentes

- **"no matches for kind Application in version argoproj.io/v1alpha1"** — Argo CD no está instalado en el cluster usado para dry-run. Es esperable sin cluster; el script lo tolera.
- **`metadata.namespace` olvidado** — el `Application` debe ir siempre en el namespace de Argo CD (normalmente `argocd`).

## Limpieza

Este ejemplo no crea recursos (solo lee y valida). Nada que limpiar.
