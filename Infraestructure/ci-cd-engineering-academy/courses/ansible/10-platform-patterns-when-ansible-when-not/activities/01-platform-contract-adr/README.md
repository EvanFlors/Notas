# Actividad 01 — Contrato de plataforma Ansible (ADR)

## 1. Identificación

- **ID:** `ans-10-01-platform-contract-adr`
- **Tecnología:** `ansible`
- **Módulo:** `ans-10-platform-patterns-when-ansible-when-not`
- **Dificultad:** advanced
- **Duración estimada:** 90–110 min
- **Tipo:** architecture (independiente — no depende de la actividad 02)

## 2. Contexto

Operas la plataforma de una scale-up de 60 ingenieros con stack mixto:

- 25 microservicios en **EKS** gestionados con Helm + Argo CD.
- 15 VMs long-lived para apps internas (BI, ETL antiguo, un bastion, 2 CI runners self-hosted).
- Infraestructura cloud **AWS** gestionada con Terraform (VPC, RDS, S3, IAM).
- Un rack bare-metal en colo con 8 servidores (datalake on-prem) y 12 switches Cisco.
- Secrets en **AWS Secrets Manager** con rotación programada.

Hoy hay un repo `ops/ansible` con 70 playbooks, dos de ellos deploys a EKS (ejecutados ocasionalmente "cuando Argo CD no responde", síntoma de nerviosismo del equipo). Un equipo nuevo acaba de proponer en RFC "usar Ansible para desplegar su servicio NestJS a Kubernetes". El director de ingeniería te pide un **documento de una página** que un tech lead pueda citar en un PR para rechazar o aceptar propuestas sin discusión filosófica.

Tu encargo: redactar el **contrato de plataforma Ansible** como ADR, que delimite:

- Dónde Ansible es la herramienta por defecto (dominios "sí").
- Dónde no (anti-patrones y herramientas correctas).
- Ownership, review, lint/CI.
- Postura immutable-first y rol de Packer.
- Control plane operacional (AWX/AAP, Event-Driven Ansible).

**Importante**: el entregable es un **documento**. No se despliega ni ejecuta nada.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Defender el contrato ante un tech lead que quiera "usar Ansible para su app EKS".
- Nombrar 5 dominios "sí" y 5 "no" con justificación de una línea cada uno.
- Explicar por qué el patrón recomendado 2026 es **Packer + Ansible → AMI** y no **Ansible sobre instancia viva**.
- Separar en el contrato "dominios donde Ansible es default", "excepciones aceptables bajo condiciones" y "anti-patrones duros".

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (especialmente §2–§4 y §10).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `ans-05`, `ans-06`, `ans-08`, `ans-09`.
- Herramientas: `bash` y un editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-10-contract
cd /tmp/ans-10-contract
```

Puedes usar otra ruta y pasársela al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-ANSIBLE-CONTRACT.md`

Formato ADR estándar:

```
# ADR 00X — Contrato de plataforma Ansible

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2–4 párrafos: stack actual, dolor que motiva el contrato, qué pasa si no se escribe.)

## Decisión
### 1. Dominios donde Ansible es la herramienta por defecto
### 2. Dominios donde Ansible NO se usa (anti-patrones)
### 3. Herramientas alternativas por dominio
### 4. Immutable-first y rol de Packer
### 5. Ownership, review y CI
### 6. Control plane operacional (AWX/AAP, EDA)
### 7. Excepciones y proceso para solicitarlas

## Consecuencias
(Positivas y negativas; qué se vuelve más fácil, qué se vuelve más caro.)

## Alternativas descartadas
(Al menos 2 alternativas y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. Encabezado con la palabra **`ADR`**.
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- Mención explícita a **Ansible** y a **al menos 3** de las siguientes alternativas: **Terraform** (u OpenTofu), **Helm**, **Argo CD** (o Flux), **Packer**, **operador K8s** / Kubernetes operator.
- **Al menos 5 dominios "sí"** (Day-2, bare metal, equipos de red, bootstrap kubeadm, incident response, hardening/CIS, etc.).
- **Al menos 3 dominios "no"** (apps en Kubernetes, aprovisionamiento cloud, configuración interna de contenedores, etc.).
- Mención a **immutable** / **inmutable** y a **Packer** como vía por defecto.
- Mención a **CODEOWNERS** (ownership de playbooks).
- Mención a **ansible-lint** y a **Molecule** como gating de CI.
- Mención a **AWX** o **AAP** (control plane) y a **Event-Driven Ansible** / **EDA** / **rulebook**.
- Un **bloque de código** con el "qué sí / qué no" (p. ej. una tabla Markdown o diagrama ASCII dentro de fences).
- **Al menos 2 alternativas descartadas** como sub-headings o items numerados.

### 5.3 Entregable

Un archivo:

```
/tmp/ans-10-contract/ADR-ANSIBLE-CONTRACT.md
```

con las 6 secciones y el contenido mínimo.

## 6. Resultado esperado

- `ADR-ANSIBLE-CONTRACT.md` existe y es coherente.
- Validador en verde (`0 issue(s)`).
- Un tech lead ajeno puede citar una fila del contrato para resolver un debate.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada dominio está justificado (no solo listado).
- **Reproducibilidad**: alguien en Fase 4 toma este ADR y lo convierte en `CONTRIBUTING.md` del repo Ansible.
- **Comunicabilidad**: una página densa, no un libro.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-10-contract
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. Un equipo quiere usar Ansible para "generar manifiestos K8s con Jinja2 y aplicarlos". ¿Lo permites? ¿Bajo qué condiciones?
2. Si mañana aparece un fleet de 400 hosts bare-metal nuevos, ¿cambia tu contrato o solo lo citas?
3. Dónde pones el límite entre "Day-2 con Ansible" y "rotar la AMI"? ¿Es por frecuencia, por riesgo o por tamaño del cambio?
4. ¿Qué hace tu contrato si un auditor te pregunta "muéstrame todo lo que Ansible ha hecho en prod los últimos 90 días"?
5. ¿Cómo mide tu organización que el contrato se cumple? ¿Lint rule? ¿Review? ¿Métrica?

## 10. Extensiones

- Añade una **tabla** `caso de uso | herramienta elegida | alternativa rechazada | razón` con 10 filas.
- Añade un **diagrama** de decisión (flowchart ASCII) "¿puedo usar Ansible para X?".
- Diseña un **lint rule custom** (concept-level) que detecte playbooks violando el contrato (p. ej. `kubectl apply` dentro de un task).

## 11. Limpieza

```bash
rm -rf /tmp/ans-10-contract
```

No hay procesos ni infraestructura que detener.
