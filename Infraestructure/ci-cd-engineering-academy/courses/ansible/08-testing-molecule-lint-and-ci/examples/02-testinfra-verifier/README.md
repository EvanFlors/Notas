# Ejemplo 02 — Verifier con Testinfra

Mismo scenario que `01`, pero el **verifier** es Testinfra (pytest). Útil cuando el equipo ya trabaja en Python y quiere escribir asserts expresivos sobre el estado del sistema.

## Cambio en `molecule.yml`

```yaml
verifier:
  name: testinfra
  options:
    verbose: true
```

## `molecule/default/tests/test_default.py`

```python
import os
import pytest
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ["MOLECULE_INVENTORY_FILE"]
).get_hosts("all")


def test_nginx_package_installed(host):
    assert host.package("nginx").is_installed


def test_nginx_service_running_and_enabled(host):
    svc = host.service("nginx")
    assert svc.is_running
    assert svc.is_enabled


def test_port_80_is_listening(host):
    assert host.socket("tcp://0.0.0.0:80").is_listening


@pytest.mark.parametrize("path", [
    "/etc/nginx/nginx.conf",
    "/etc/nginx/sites-enabled/default",
])
def test_config_files_exist(host, path):
    f = host.file(path)
    assert f.exists
    assert f.user == "root"
```

## Dependencias

```
pip install molecule 'molecule-plugins[docker]' pytest-testinfra docker
```

## Cuándo elegirlo

- Ya tienes pytest en el proyecto (fixtures, parametrize, coverage).
- Quieres asertar propiedades que Ansible no modela cómodamente (p. ej. "este socket responde en < 50 ms").
- No te importa añadir `pytest-testinfra` a `requirements.txt`.

Para la mayoría de roles pequeños, Ansible asserts es suficiente y evita la dependencia extra.
