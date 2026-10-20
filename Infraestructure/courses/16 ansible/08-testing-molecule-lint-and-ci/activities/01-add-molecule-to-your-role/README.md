# Actividad 01 — Añadir Molecule, ansible-lint y yamllint a un role

## 1. Identificación

- **ID:** `ans-08-01-add-molecule-to-your-role`
- **Tecnología:** `ansible`
- **Módulo:** `ans-08-testing-molecule-lint-and-ci`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab

## 2. Contexto

Heredas un role `nginx-site` que funciona en tu laptop pero no tiene tests, ni lint, ni CI. En la próxima retro, tu equipo decidió que "ningún role entra a producción sin Molecule + lint + idempotencia probada". Te toca a ti ser el primer caso.

El starter trae el role **ya escrito** (tasks, handlers, templates, defaults). Tu trabajo es **añadirle** la capa de testing: scenario de Molecule con driver Docker, configuración de `ansible-lint` y `yamllint`, un `requirements.txt` que fije versiones, y un `verify.yml` que compruebe estado del servicio.

**Importante**: el ciclo completo `molecule test` requiere Docker. El validador *estructural* corre siempre; el *smoke* de Molecule se **salta** si Docker no está disponible y lo deja anotado en el reporte.

## 3. Objetivos

Al terminar deberías poder:

- Añadir un scenario `default/` con `molecule.yml`, `converge.yml` y `verify.yml`.
- Configurar `.ansible-lint` (perfil `production`) y `.yamllint` con reglas razonables.
- Fijar versiones en `requirements.txt` (y opcionalmente `requirements.yml` para collections).
- Interpretar un fallo de `idempotence` y arreglarlo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` y recorrido los 3 `examples/` del módulo.
- Haber completado `ans-04` (saber qué es un role y cómo se descompone).
- Herramientas: `bash`, Python 3.10+, `pip`. Deseable: Docker (para correr `molecule test` end-to-end). Si no hay Docker, la validación estructural igual pasa.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-08-01
cp -R starter/ /tmp/ans-08-01/
cd /tmp/ans-08-01
```

Puedes usar otro directorio pasándoselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Archivos a producir

El starter trae ya el role (tasks/handlers/templates/defaults/meta). Debes crear/completar:

```
/tmp/ans-08-01/
├── (role existente: tasks/, handlers/, templates/, defaults/, meta/)
├── .ansible-lint
├── .yamllint
├── requirements.txt
├── requirements.yml                      # opcional pero recomendado
└── molecule/
    └── default/
        ├── molecule.yml
        ├── converge.yml
        └── verify.yml
```

### 5.3 `requirements.txt`

Fija versiones (el validador comprueba que menciona los tres paquetes):

```
ansible-core>=2.16,<2.19
ansible-lint>=24.0
yamllint>=1.35
molecule>=24.0
molecule-plugins[docker]>=23.5
docker>=7.0
```

### 5.4 `.ansible-lint`

```yaml
---
profile: production
exclude_paths:
  - .cache/
  - .github/
  - molecule/
skip_list: []
```

### 5.5 `.yamllint`

```yaml
---
extends: default
rules:
  line-length:
    max: 160
  truthy:
    allowed-values: ["true", "false"]
```

### 5.6 `molecule/default/molecule.yml`

Debe declarar:

- `driver.name: docker`
- `platforms` con al menos una entrada con `image:` que apunte a una `geerlingguy/*-ansible` (p. ej. `geerlingguy/docker-ubuntu2204-ansible:latest`).
- `provisioner.name: ansible`
- `verifier.name: ansible`

### 5.7 `molecule/default/converge.yml`

Un play que haga `become: true` e **incluya el role** bajo test con `ansible.builtin.include_role` o `roles:`.

### 5.8 `molecule/default/verify.yml`

Un play con `gather_facts: false` y al menos un `ansible.builtin.assert` que compruebe algo real del role (p. ej. que el servicio está corriendo).

### 5.9 Ejecutar (opcional pero recomendado)

Si tienes Docker:

```bash
cd /tmp/ans-08-01
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
molecule test
```

El ciclo esperado:

```
INFO     Running default > destroy
INFO     Running default > create
INFO     Running default > converge   # 1a pasada: changed=N
INFO     Running default > idempotence  # 2a pasada: changed=0  <- clave
INFO     Running default > verify
INFO     Running default > destroy
```

### 5.10 Entregable

```
/tmp/ans-08-01/
├── .ansible-lint
├── .yamllint
├── requirements.txt
├── molecule/default/molecule.yml
├── molecule/default/converge.yml
└── molecule/default/verify.yml
```

## 6. Resultado esperado

- Los seis archivos existen con contenido mínimo.
- `yamllint` acepta los YAMLs del scenario.
- (Si hay Docker) `molecule test` pasa el ciclo completo con idempotencia.
- `bash tests/validate.sh /tmp/ans-08-01` reporta `0 issue(s)`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural en verde.
- **Calidad**: `ansible-lint` sin errores; `yamllint` sin errores en los archivos de scenario.
- **Reproducibilidad**: cualquier compañero puede clonar el role y correr `molecule test`.
- **Mantenibilidad**: versiones fijadas en `requirements.txt`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-08-01
```

El validador comprueba **estructura y claves mínimas** de cada archivo. Si Docker está instalado, intenta además `molecule --version` como smoke. **No** aplica el role en una cuenta real.

## 9. Preguntas de reflexión

1. ¿Por qué `idempotence` es la fase que más fallos revela en roles heredados?
2. ¿Qué cambia si usas Podman en vez de Docker? ¿Vale la pena para tu equipo?
3. Si tu role instala paquetes distintos según distro, ¿cómo lo pruebas en la matriz?
4. ¿Cuándo pasarías a Testinfra en vez de asserts nativos?
5. ¿Qué parte del ciclo `molecule test` **no** necesitas correr en cada PR y sí en el nightly?

## 10. Extensiones

- Añade un segundo scenario (`molecule/debian/`) apuntando a `geerlingguy/docker-debian12-ansible:latest`.
- Añade `prepare.yml` que precargue un apt cache si tu distro de pruebas lo requiere.
- Añade un fixture Testinfra para asertar el puerto HTTP.

## 11. Limpieza

```bash
rm -rf /tmp/ans-08-01
```
