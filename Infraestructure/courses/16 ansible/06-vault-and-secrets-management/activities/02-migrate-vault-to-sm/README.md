# Actividad 02 — ADR: migrar de `ansible-vault` a secret manager externo

## 1. Identificación

- **ID:** `ans-06-02-migrate-vault-to-sm`
- **Tecnología:** `ansible`
- **Módulo:** `ans-06-vault-and-secrets-management`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un equipo de plataforma de 8 personas opera 14 playbooks Ansible contra 60 hosts EC2 en 3 cuentas AWS (dev, stg, prod). Hoy todos los secretos viven en archivos encriptados con **una sola vault password** compartida por Slack el día que entra una persona nueva. Problemas reportados:

- Un ingeniero que dejó el equipo hace 2 meses todavía tiene la password en su laptop.
- Nadie ha rotado la password en 14 meses.
- No se puede auditar quién leyó `rds_master_password`.
- La misma password protege dev y prod.

Dirección pide un ADR con el **camino de migración** a algo mejor. Hay presupuesto para **AWS Secrets Manager** (ya usan AWS). Tienes la opción de intermediar con **SOPS** si lo justificas; **External Secrets Operator** solo aplica para una app futura que irá a EKS.

**Importante — ningún secreto real.** El ADR es un documento; cualquier ejemplo YAML usa valores `fake-...`.

## 3. Objetivos

- Diagnosticar por escrito por qué el estado actual es insostenible.
- Proponer un **estado objetivo** por tipo de secreto (ver tabla en §5.3).
- Diseñar el **snippet Ansible** que reemplaza `rds_master_password` con un lookup a AWS Secrets Manager.
- Comparar `ansible-vault`, SOPS y ESO con criterios explícitos (cifrado, diffs, rotación, auditoría, dependencia operativa).
- Listar al menos 2 **alternativas descartadas** y por qué.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` secciones 7–8 (lookups a SM, SOPS/ESO).
- Haber recorrido `examples/03-sops-vs-external-secrets/`.
- Herramientas: `bash` y un editor Markdown.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-06-sm
cd /tmp/ans-06-sm
```

### 5.2 Escribir `ADR-SECRETS-MIGRATION.md`

Formato ADR estándar. **Secciones obligatorias** (el validador las busca):

1. `# ADR` (encabezado con la palabra "ADR").
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decisión` (o `Decision`).
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives` — al menos 2 descartadas).

### 5.3 Contenido mínimo exigido

El validador comprueba que el ADR mencione:

- **Herramientas comparadas**: `ansible-vault`, `SOPS`, `External Secrets` (o `ESO`) y `AWS Secrets Manager` (o `HashiCorp Vault` como equivalente aceptado).
- **Lookup Ansible**: una referencia a `amazon.aws.aws_secret` o `community.hashi_vault` dentro de un bloque de código.
- **`no_log`**: mención del task keyword que evita leaks en stdout.
- **Rotación**: comparar cómo rota cada herramienta.
- **Tabla o lista con al menos 3 ejes de comparación** (ejemplo: cifrado, diffs, rotación, auditoría, dependencia externa).
- **Mapa de secretos**: al menos los 3 ejemplos del contexto (`rds_master_password`, `api_token_stripe`, `ssh_deploy_key`) y a dónde migra cada uno.
- Mención de `fake-password-not-real` en los snippets, dejando claro que no hay secretos reales.

### 5.4 Entregable

Un único archivo:

```
/tmp/ans-06-sm/ADR-SECRETS-MIGRATION.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- ADR coherente que un ingeniero externo pueda leer y ejecutar.
- Decisión explícita: para cada tipo de secreto, dónde vive mañana.
- Snippet Ansible con lookup + `no_log: true`.
- Validador en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Calidad**: cada decisión justificada (por qué, no solo qué).
- **Reproducibilidad**: el snippet Ansible es sintácticamente válido (puedes copiarlo a un playbook y correrlo con credenciales simuladas).
- **Mantenibilidad**: Markdown válido; snippets en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-06-sm
```

El validador comprueba estructura y presencia de tokens clave, **no** semántica. Compara tu ADR con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué SOPS puede ser una buena **etapa intermedia** entre `ansible-vault` y el lookup directo a SM?
2. Si el equipo de la app EKS pide "igual que vosotros pero en K8s", ¿qué les dices? ¿Lookup Ansible? ¿ESO? ¿Ambos?
3. ¿Qué pasa con el deploy el día que AWS Secrets Manager tiene un outage regional?
4. ¿Cómo rotarías `rds_master_password` **sin downtime** usando AWS SM + Lambda rotation?
5. ¿Qué controles IAM son el **techo** de este diseño (quién puede leer qué SM path)?

## 10. Extensiones

- Añade un **plan de corte** en fases (fase 1: migrar `rds_master_password`; fase 2: migrar tokens de API; fase 3: eliminar `ansible-vault`).
- Añade una sección **"Rollback"** con cómo volver a `ansible-vault` si SM falla.
- Diseña una **matriz RACI** (Responsible/Accountable/Consulted/Informed) para la migración.

## 11. Limpieza

```bash
rm -rf /tmp/ans-06-sm
```
