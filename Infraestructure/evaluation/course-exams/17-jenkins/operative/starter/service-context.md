# Contexto — servicio `payments-api`

- **Lenguaje:** Node.js 20 (TypeScript).
- **Test runner:** Jest con `jest-junit` para reporte JUnit (`junit.xml`).
- **Linter:** ESLint invocado por `npm run lint`.
- **Registry destino:** `registry.corp.internal` (interno, autenticación por usuario + token).
- **Deploy target:** AWS (role `arn:aws:iam::123456789012:role/payments-deployer`, región `us-east-1`).
  - El cluster on-prem de Jenkins **sí** tiene conectividad al endpoint STS para OIDC federation.
- **Shared Library disponible:** `platform-lib` (ya instalada en el controller), con tag estable `v1.4.2`.
  - Provee los steps `standardCheckout()`, `publishImage(name, tag)`, `deployToEnv(env, tag)`.
- **Agents disponibles:** cloud Kubernetes configurado en JCasC con namespace `jenkins-agents`.
  - Imágenes permitidas: `jenkins/inbound-agent:latest-jdk17`, `node:20-bookworm-slim`.
- **Política interna:**
  - Prohibido ocupar executors del controller durante gates manuales.
  - Prohibido escribir credenciales a disco o environment global.
  - Prohibido Shared Libraries sin pin de versión.
  - El deploy a `main` requiere aprobación manual con timeout razonable (≤ 24 h).

El `Jenkinsfile` entregable debe reflejar estas restricciones y cubrir los stages equivalentes a los jobs del workflow GHA de referencia.
