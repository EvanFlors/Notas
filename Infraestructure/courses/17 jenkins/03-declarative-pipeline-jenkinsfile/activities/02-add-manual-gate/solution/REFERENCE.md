# Referencia semántica — jk-03-02

Esta referencia justifica las decisiones del `solution/Jenkinsfile`.

## Anatomía del gate

```groovy
stage('Approve prod deploy') {
  when { branch 'main' }
  steps {
    timeout(time: 15, unit: 'MINUTES') {
      input message: '¿Desplegar a producción?',
            ok: 'Desplegar',
            submitter: 'release-managers',
            submitterParameter: 'APPROVER'
    }
  }
}
```

| Elemento | Razón |
|----------|-------|
| `when { branch 'main' }` | El gate sólo tiene sentido en ramas que generan releases. En PRs o feature branches, aparecería inutilmente y bloquearía executors. |
| `timeout(time: 15, unit: 'MINUTES')` envolviendo el `input` | Sin timeout, un gate olvidado consume indefinidamente un executor y un slot del controller. 15 min es razonable para releases planificadas; para releases nocturnas, podría ser más alto. |
| `message` humano | Lo lee la persona que aprueba. Debe decir **qué** se despliega, no sólo "¿aprobar?". |
| `ok: 'Desplegar'` | Confirma la acción en el botón, evita el genérico "Proceed". |
| `submitter: 'release-managers'` | Restringe la aprobación a un **grupo** definido en el security realm (LDAP/SAML/Role Strategy). Nunca a un usuario concreto: no escala y rompe cuando esa persona está de vacaciones. |
| `submitterParameter: 'APPROVER'` | Expone el username del aprobador en una variable del build — crítico para auditoría. |

## Por qué `post { aborted }` es obligatorio

Si el `timeout` del `input` expira, o si alguien cancela el gate, el build pasa a estado `aborted` (no `failure`). Sin `post { aborted { ... } }`:

- No notificas a nadie: el equipo se entera horas después mirando el dashboard.
- Posibles recursos a medias (p. ej. `docker push` ya hecho, deploy a staging ya aplicado) quedan sin registro de que la release no completó.

## Diferencias con un gate "mal hecho"

| Antipatrón | Qué duele |
|------------|-----------|
| `input` sin `timeout` | Build colgado para siempre, executor ocupado, builds siguientes en cola. |
| `input` sin `submitter` | Cualquier usuario con permiso de build puede aprobar un deploy a prod — fallo de 4-ojos. |
| `input` sin `when` | El gate aparece también en ramas feature, confundiendo a los developers. |
| `input` dentro de un stage con `agent { docker { ... } }` | El contenedor queda vivo esperando — malgasto de recursos del nodo. Mejor: stage de gate con `agent none` o sin `agent` explícito. |
| `submitter: 'alice'` | Blocking de releases cuando Alice no está. Siempre un grupo. |
| `message: 'Approve?'` sin contexto | Quien aprueba no sabe qué se despliega — aprueba por reflejo. |

## Comparación con GHA

En GitHub Actions, el equivalente son **Environment protection rules**:

```yaml
jobs:
  deploy-prod:
    environment:
      name: production
      # UI configurable: required reviewers (group or users), wait timer, etc.
```

Diferencias:

- GHA fija el gate en la configuración del **environment** (UI), no en el workflow. Es más declarativo y menos "codable". En Jenkins, el gate vive en el `Jenkinsfile` (más versionable, más visible en PR review).
- GHA permite "wait timer" (ventana forzada antes de poder aprobar) sin plugin extra. En Jenkins se emula con `sleep` + `input`.
- La auditoría de "quién aprobó" es nativa en ambos (en Jenkins vía `submitterParameter` + logs del build).

## Auditoría

Para contestar "¿quién aprobó el deploy a prod del release X el día Y?":

1. En la Build History, abre el build de prod.
2. En **Pipeline Steps**, localiza el step `input` y verás el usuario que aprobó.
3. Si usas `submitterParameter: 'APPROVER'`, el username queda en los logs y en el env del stage siguiente — puedes archivarlo con `archiveArtifacts` en un fichero `APPROVER.txt`.
4. Para auditoría externa, el `Audit Trail` plugin registra inputs aprobados en un fichero separado.
