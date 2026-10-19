# Rationale de los plugins instalados

Documento vivo. Si añades un plugin al `plugins.txt`, añade una entrada aquí.

| Plugin | Para qué | Alternativa descartada |
|--------|----------|------------------------|
| `configuration-as-code` | Permite describir el controller en `jenkins.yaml`. Sin esto no hay módulo. | No hay alternativa oficial. |
| `job-dsl` | Generar jobs desde Groovy en el seed job. | Dejar los jobs legacy sin versionar (inaceptable). |
| `workflow-aggregator` | Meta-plugin que arrastra todo lo necesario para `pipeline {}` declarative y scripted. | Instalar los sub-plugins uno a uno (frágil). |
| `pipeline-model-definition` | Soporte explícito del DSL declarativo. | Ya viene con workflow-aggregator; pinneado para claridad. |
| `credentials` + `credentials-binding` | Store de credenciales + `withCredentials` en pipelines. | No hay alternativa. |
| `role-strategy` | RBAC granular por rol y folder. Necesario para `jk-07`. | `matrix-auth` solo (menos flexible para orgs grandes). |
| `matrix-auth` | Autorización matriz como fallback / compatibilidad. | Omitir, pero algunas instalaciones legacy lo requieren. |
| `git` + `github` + `github-branch-source` | SCM GitHub + Multibranch desde organización. | GitLab plugin si fuera GitLab. |
| `kubernetes` + `kubernetes-credentials-provider` | Cloud K8s para agents efímeros (ver `jk-05`). | Docker plugin plano (menos escalable). |
| `slack` | Notificaciones de pipeline. | Email (frío), webhook crudo (reinventar la rueda). |
| `docker-workflow` | `agent { docker { image '…' } }` en pipelines. | No usarlo (atar todo a K8s). |
| `timestamper` | Timestamps en logs. Trivial pero muy útil para debugging. | Sin él, los logs son opacos cronológicamente. |
| `ws-cleanup` | `cleanWs()` al final de pipelines. | Dejar workspaces sucios (contamination entre builds). |

## Plugins deliberadamente ausentes

- **`blueocean`**: ver §5 de `theory/lesson.md`. Estado *low-maintenance*; no es la UI por defecto. Añadir solo bajo demanda del equipo.
- **`ssh-slaves`**: no usamos agents SSH; todo es Kubernetes.
- **`maven-plugin` legacy (jobs maven freestyle)**: `pipeline { }` + `sh 'mvn …'` ya cubre el caso.
- **Plugins "recomendados" del setup wizard**: la mitad son innecesarios y suman superficie de CVE.
