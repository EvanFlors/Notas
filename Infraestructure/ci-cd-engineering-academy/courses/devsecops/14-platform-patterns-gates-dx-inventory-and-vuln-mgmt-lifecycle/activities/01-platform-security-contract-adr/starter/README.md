# Starter — sec-14-01-platform-security-contract-adr

Esta actividad es **independiente**: no hay código ni plantilla ejecutable. Tu entregable es un documento Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-14-contract
   cd /tmp/sec-14-contract
   ```
3. Crea `ADR-security-contract.md` con las 7 secciones mínimas (contexto, decisión, gates con tabla, política severidad CVSS+EPSS+KEV, exception policy, DX, consecuencias).
4. Opcional: puedes copiar y adaptar `../../../examples/01-gates-contract/TEMPLATE.md` como punto de partida, pero el ADR debe estar escrito con tus propias justificaciones.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle/activities/01-platform-security-contract-adr/tests/validate.sh /tmp/sec-14-contract
   ```
6. Compara con `../solution/REFERENCE.md` para autoevaluarte.

> El validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.
