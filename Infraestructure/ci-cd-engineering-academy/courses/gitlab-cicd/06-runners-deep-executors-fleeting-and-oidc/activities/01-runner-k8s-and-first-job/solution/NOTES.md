# NOTES — gl-06-01

## Decisión

Operamos un GitLab Runner **compartido** en el namespace `gitlab-runner` del cluster EKS `platform-eu-west-1`, instalado con el chart `gitlab/gitlab-runner` y pre-registrado con un *authentication token* moderno (`glrt-...`). Los jobs corren en pods efímeros con `privileged = false`, límites de CPU/memoria explícitos y un `node_selector` que los fija al node group `workload=ci`.

Builds de imágenes OCI se hacen con **Kaniko** rootless. No habilitamos DinD en el runner compartido.

## Por qué no DinD

1. DinD exige `privileged = true` en el pod del service `docker:dind`. Esto le da al pod capacidades (`CAP_SYS_ADMIN` entre otras) que permiten escapar al nodo con facilidad conocida; en un cluster multi-tenant, es una puerta trasera para pivot a otros pods.
2. Cada daemon de DinD arranca **vacío**: no hay cache de capas entre jobs, los builds son más lentos y consumen más ancho de banda hacia el registry.
3. Operacionalmente, DinD obliga a mantener `DOCKER_TLS_CERTDIR` y la red del service correctamente; errores sutiles (TLS mal) exponen el daemon a otros pods del nodo.
4. Kaniko (y BuildKit rootless) producen el mismo artefacto (imagen OCI empujada al registry) sin daemon, sin `privileged`, y con cache remoto reutilizable entre jobs.

Si un pipeline **heredado** requiere DinD, lo aislamos en un segundo `[[runners]]` con `tags: "dind,legacy"` y `privileged = true`, y documentamos la excepción.

## Cache S3 e IRSA

La cache compartida de `node_modules`, `.gradle` y `.m2` vive en el bucket `gitlab-runner-cache-prod` (región `eu-west-1`). El `values.yaml` configura `AuthenticationType = "iam"` para que los pods de los jobs usen el role del `ServiceAccount` `gitlab-runner`, al que la anotación `eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/gitlab-runner-irsa` asocia un role IAM mediante **IRSA** (IAM Roles for Service Accounts). Consecuencia: no hay `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` en el chart ni en variables de GitLab para la cache.
