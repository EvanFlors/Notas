# Solución de referencia — ans-08-01

Esta solución **cubre todos los chequeos del validador**. Compara campo a campo con tu entrega.

## Archivos entregados

```
.ansible-lint
.yamllint
requirements.txt
molecule/default/molecule.yml
molecule/default/converge.yml
molecule/default/verify.yml
```

## Decisiones clave

- **Driver Docker + imagen `geerlingguy/*-ansible`** con `pre_build_image: true`. Evita reinstalar Ansible dentro del contenedor en cada run. `cgroupns_mode: host` + montaje de `/sys/fs/cgroup` permiten probar servicios systemd reales.
- **`MOLECULE_DISTRO` como variable env** en `image:`. Deja la matriz CI parametrizar la distro sin tocar el YAML.
- **Verifier `ansible`** con `service_facts` y `assert`. Mantiene la dependencia a cero.
- **Perfil `production` en `ansible-lint`**. Es el techo razonable para un role publicable.
- **Versiones fijadas en `requirements.txt`**. Evita que un bump silencioso de `ansible-lint` rompa CI al día siguiente.

## Si Molecule corre localmente

Esperado:

```
INFO     Running default > destroy
INFO     Running default > create
INFO     Running default > converge     # changed=3
INFO     Running default > idempotence  # changed=0  (clave)
INFO     Running default > verify       # 2 asserts OK
INFO     Running default > destroy
```

## Antipatterns a evitar

- `shell:` sin `creates:`/`changed_when:` → romperá idempotence.
- Falta de `name:` en tareas → `ansible-lint` lo marca.
- Templates sin `mode:` → marca el perfil `safety`.
- `verify.yml` con un solo `debug:` que no asertea nada → no es test, es observación.
