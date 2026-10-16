# Ejemplo 02 — Exportar SARIF a GitHub Code Scanning

> Lectura y análisis. No requiere ejecución; la actividad `01` puede generarlo si tienes repo con permisos.

## 1. Por qué SARIF

El ejemplo `01` tira hallazgos como **log de job**: útil pero efímero. SARIF los convierte en **alerts persistentes** en la pestaña *Security → Code scanning* del repo, con:

- Estado de la alert (`open`, `dismissed`, `fixed`).
- Fix suggestion automática cuando hay versión parcheada.
- Trazabilidad: cuándo apareció, en qué commit, cuándo se cerró.
- **PR annotations**: comentarios inline en el PR solo sobre las CVEs **nuevas** introducidas en ese PR.

SARIF (Static Analysis Results Interchange Format) es el estándar OASIS que GitHub Code Scanning ingiere. Trivy lo emite nativamente con `--format sarif`.

## 2. Prerrequisitos del repo

- Repo público, o repo privado con **GitHub Advanced Security** habilitado (los repos públicos tienen Code Scanning gratis).
- Permiso `security-events: write` en el workflow.

## 3. El workflow comentado

```yaml
name: container-scan-sarif

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write    # <-- clave para upload-sarif
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:${{ github.sha }} .

      # Step 1 — producir SARIF SIN fallar aqui.
      - name: Trivy scan (SARIF output)
        uses: aquasecurity/trivy-action@0.24.0
        with:
          image-ref: app:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          ignore-unfixed: true
          exit-code: '0'               # <-- NO fallamos aqui; necesitamos subir el SARIF

      - name: Upload SARIF to Code Scanning
        uses: github/codeql-action/upload-sarif@v3
        if: always()                   # <-- siempre, incluso si el scan tiraria errores
        with:
          sarif_file: trivy-results.sarif
          category: trivy-image

      # Step 2 — gate real. Si CRITICAL con fix, aqui si fallamos.
      - name: Fail on CRITICAL (unignored, with fix)
        run: |
          docker run --rm \
            -v "$HOME/.cache/trivy:/root/.cache/trivy" \
            -v "$PWD/.trivyignore:/.trivyignore" \
            aquasec/trivy:0.56.2 image \
            --severity CRITICAL \
            --exit-code 1 \
            --ignore-unfixed \
            --ignorefile /.trivyignore \
            app:${{ github.sha }}
```

## 4. La separación en dos pasadas no es casualidad

Mucha gente intenta hacer **una sola** pasada con `format: sarif + exit-code: 1`. Problema: si Trivy sale con `1`, el step **falla** y el **siguiente step no corre** por defecto. El `upload-sarif` no se ejecuta y pierdes la visibilidad en la pestaña Security.

Las dos variantes para evitarlo:

**A) Dos pasadas (la de arriba, recomendada)**: el SARIF se produce con `exit-code: 0`, se sube, y un step aparte decide el gate.

**B) Una pasada + `if: always()` en el upload**: funciona pero es más frágil (depende de que el SARIF se haya escrito antes del exit non-zero).

## 5. Cómo lo ves en la UI de GitHub

- `Security → Code scanning alerts`: lista todas las alerts, filtrable por severidad, tool, branch.
- Al abrir una alert: título de la CVE, descripción, severidad, fix, link al Dockerfile/línea responsable, botón **Dismiss** (con razón: *false positive*, *won't fix*, *used in test*).
- En un PR: tab *Files changed* muestra comments inline en las líneas afectadas; tab *Checks* muestra el summary.

## 6. `category` y por qué separar scanners

Si corres **varios scanners** (Trivy, CodeQL, Semgrep) sobre el mismo repo, pasa cada uno con un **`category` distinto** al `upload-sarif`:

```yaml
with:
  sarif_file: trivy-results.sarif
  category: trivy-image      # distinto de 'codeql-python' o 'semgrep'
```

Sin la `category`, cada subida **sobreescribe** la anterior y pierdes alerts del otro scanner. Con `category` separado, las alerts de los distintos scanners coexisten.

## 7. Suppressions: `.trivyignore` vs *Dismiss* en UI

Dos vías para suprimir:

- **`.trivyignore` / `.trivyignore.yaml` en el repo**: la suppression es **declarativa, versionada, revisable en PR**. Preferida siempre que sea posible.
- **Dismiss desde la UI de GitHub**: queda registrado en el audit log pero **no viaja** entre repos ni se refleja en runs posteriores de Trivy local. Útil para falsos positivos muy específicos del tooling de GitHub.

Regla operativa: suppressions "para el pipeline" van en `.trivyignore.yaml` con razón y expiración; dismisses en UI solo para falsos positivos reconocidos de Code Scanning.

## 8. Vistazo al SARIF generado (abreviado)

```json
{
  "version": "2.1.0",
  "runs": [{
    "tool": { "driver": { "name": "Trivy", "version": "0.56.2" } },
    "results": [
      {
        "ruleId": "CVE-2024-5535",
        "level": "error",
        "message": { "text": "openssl: info leak..." },
        "locations": [{
          "physicalLocation": {
            "artifactLocation": { "uri": "app:abc1234" },
            "region": { "startLine": 1 }
          }
        }]
      }
    ]
  }]
}
```

GitHub lo ingiere y lo renderiza como alert con el `ruleId` como título.

## 9. Preguntas de reflexión

1. ¿Qué pasa si olvidas `permissions: security-events: write`?
2. ¿Por qué `if: always()` en el upload es más defensivo que confiar en el orden de steps?
3. Si una CVE aparece en Code Scanning y la *dismisseas* desde la UI, ¿reaparece en el siguiente scan local con Trivy? ¿Y en el siguiente scan en CI?
4. ¿Cuál es la diferencia práctica entre el gate `exit-code 1` y marcar la alert como *required check* en branch protection?
