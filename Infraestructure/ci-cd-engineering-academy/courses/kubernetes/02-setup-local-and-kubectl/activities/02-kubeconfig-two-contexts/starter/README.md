# Starter — k8s-02-02-kubeconfig-two-contexts

Esta es una actividad **independiente**. No hay plantillas de código ni soluciones aquí: trabajas en `/tmp/k8s-02-02/`.

Resumen de lo que el validador espera (lee el README principal para detalles):

- Clusters kind: `lab-dev` y `lab-stg`.
- Contextos: `kind-lab-dev` y `kind-lab-stg`.
- Namespace `apps-dev` como default del contexto `kind-lab-dev`, con un ConfigMap `env-marker` donde `data.env=dev`.
- Namespace `apps-stg` como default del contexto `kind-lab-stg`, con un ConfigMap `env-marker` donde `data.env=stg`.
- `/tmp/k8s-02-02/switch.sh` ejecutable, que acepta `dev` o `stg`.

Pistas en el README principal.
