# Ejemplo 02 — Inspector + ECR scanning

> Lectura y análisis. **No se despliega**. Objetivo: entender la diferencia operativa y de costo entre ECR basic scanning y Inspector v2 enhanced, y cómo se lee un finding.

## 1. Lado a lado

```
┌─────────────────────────────────────────┬─────────────────────────────────────────┐
│ BASIC scanning (gratis)                 │ ENHANCED scanning (Inspector v2)        │
├─────────────────────────────────────────┼─────────────────────────────────────────┤
│ Motor: Clair                            │ Motor: Inspector v2                     │
│ Scope: paquetes de OS                   │ Scope: OS + librerias de lenguaje       │
│                                          │   (pip, npm, Go mod, Maven, NuGet, Gem) │
│ Trigger: on push (y manual)             │ Trigger: on push + CONTINUO             │
│ Reescaneo si aparece CVE nueva: no      │ Reescaneo si aparece CVE nueva: SI      │
│                                          │                                         │
│ Findings: ECR API                       │ Findings: ECR API + Security Hub +      │
│                                          │   EventBridge events                    │
│                                          │                                         │
│ Costo: $0                               │ Costo: ~$0.09 por imagen por mes (ref)  │
│   (solo storage ECR $0.10/GB-mes)       │   verificar en Fase 4                   │
└─────────────────────────────────────────┴─────────────────────────────────────────┘
```

## 2. Terraform (ejemplo de **referencia**, no se aplica)

```hcl
# Basic scanning: por repositorio
resource "aws_ecr_repository" "app" {
  name = "mirepo/app"

  image_scanning_configuration {
    scan_on_push = true    # basic scanning
  }

  image_tag_mutability = "IMMUTABLE"
}

# Enhanced scanning: por cuenta/region, cubre todos los repos
resource "aws_ecr_registry_scanning_configuration" "enhanced" {
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}
```

Observación: enhanced se activa **a nivel de registry** (toda la cuenta/region). Basic es por repo.

## 3. Lectura de un finding (ejemplo redactado)

```json
{
  "imageScanFindings": {
    "imageScanCompletedAt": "2026-10-15T10:12:03Z",
    "vulnerabilitySourceUpdatedAt": "2026-10-14T22:00:00Z",
    "findings": [
      {
        "name": "CVE-2024-XXXX",
        "severity": "CRITICAL",
        "description": "Buffer overflow in libxyz 1.2.3",
        "uri": "https://nvd.nist.gov/vuln/detail/CVE-2024-XXXX",
        "attributes": [
          { "key": "package_name",    "value": "libxyz" },
          { "key": "package_version", "value": "1.2.3-1" },
          { "key": "CVSS2_SCORE",     "value": "9.8" }
        ]
      }
    ],
    "findingSeverityCounts": { "CRITICAL": 1, "HIGH": 3, "MEDIUM": 12 }
  },
  "imageScanStatus": { "status": "COMPLETE", "description": "The scan was completed successfully." }
}
```

Lo que importa en el gate del pipeline:

- `imageScanStatus.status == "COMPLETE"` (hay que **esperar**).
- `findingSeverityCounts.CRITICAL + findingSeverityCounts.HIGH`.
- Si el total supera un umbral (típicamente **0 CRITICAL**, y HIGH según política), el job falla.

## 4. Gate en pipeline — pseudocódigo bash

```bash
# tras docker push
aws ecr wait image-scan-complete \
  --repository-name mirepo/app --image-id imageTag=latest

CRITICAL=$(aws ecr describe-image-scan-findings \
  --repository-name mirepo/app --image-id imageTag=latest \
  --query 'imageScanFindings.findingSeverityCounts.CRITICAL' --output text)

if [ "$CRITICAL" != "None" ] && [ "$CRITICAL" -gt 0 ]; then
  echo "FAIL: $CRITICAL CRITICAL vulnerabilities found"
  exit 1
fi
```

## 5. Cuándo elegir cuál

| Contexto | Recomendación |
|----------|---------------|
| Producción, muchas dependencias de lenguaje | **Enhanced**. Las CVEs de pip/npm son el 80% de los hallazgos reales. |
| Producción, imagen distroless mínima | Basic suele bastar; enhanced si quieres continuo. |
| Sandbox personal | Basic. Enhanced sería gasto gratuito. |
| Imágenes compartidas entre dev y prod | Enhanced en la cuenta de prod; basic en dev. |

## 6. Preguntas

1. Si una CVE nueva (publicada **después** del push) afecta a tu imagen en producción, ¿cuál de los dos modos te avisa sin acción humana?
2. ¿Por qué `image_tag_mutability = "IMMUTABLE"` es relevante para la seguridad del scanning?
3. Si tu base image es `distroless` y la app es Python con 150 dependencias pip, ¿basic basta?
4. ¿Qué permiso IAM mínimo necesita el pipeline para leer findings? ¿Y para hacer push?
