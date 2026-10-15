# Ejemplo 01 — Visualización del grafo con `terraform graph`

Objetivo: ver con tus propios ojos el DAG que Terraform construye a partir de un stack trivial, y notar cómo cambian las aristas cuando añades `depends_on`.

## Prerrequisitos

- Terraform ≥ 1.5.
- Opcional: `graphviz` (binario `dot`). Si no lo tienes, lees el DOT en texto plano (está diseñado para ser legible).

Instalación opcional de `dot`:

- macOS: `brew install graphviz`
- Linux (apt): `sudo apt-get install -y graphviz`

## Setup

```bash
mkdir -p /tmp/tf-10-ex01 && cd /tmp/tf-10-ex01

cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
}

resource "random_pet" "name" {
  length = 2
}

resource "random_integer" "port" {
  min = 8000
  max = 8999
}

resource "local_file" "report" {
  filename = "${path.module}/out/report.txt"
  content  = "service=${random_pet.name.id} port=${random_integer.port.result}\n"
}
EOF

terraform init
```

## Pasos

### 1. Grafo por defecto (apply)

```bash
terraform graph > graph-apply.dot
head -40 graph-apply.dot
```

Observa en el DOT:

- Un nodo `[root] random_pet.name`, otro `[root] random_integer.port`, otro `[root] local_file.report`.
- Aristas: `local_file.report -> random_pet.name` y `local_file.report -> random_integer.port` (porque los referencia por interpolación).
- Un nodo `provider["registry.terraform.io/hashicorp/random"]` y otro para `local`, con aristas hacia los recursos que gestionan.

### 2. Grafo del plan y del plan-refresh-only

```bash
terraform graph -type=plan              > graph-plan.dot
terraform graph -type=plan-refresh-only > graph-refresh.dot
diff graph-plan.dot graph-refresh.dot | head -20
```

El grafo de `plan-refresh-only` incluye los nodos de refresh pero omite el walk de "proponer cambios de config".

### 3. Añadir una dependencia explícita y comparar

```bash
cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
}

resource "random_pet" "name" {
  length = 2
}

resource "random_integer" "port" {
  min = 8000
  max = 8999
  # Dependencia artificial: port "espera" a name sin referenciarlo.
  depends_on = [random_pet.name]
}

resource "local_file" "report" {
  filename = "${path.module}/out/report.txt"
  content  = "service=${random_pet.name.id} port=${random_integer.port.result}\n"
}
EOF

terraform graph > graph-apply-with-depends.dot
diff graph-apply.dot graph-apply-with-depends.dot
```

Verás una arista nueva: `random_integer.port -> random_pet.name`. Antes no estaba porque no había referencia; `depends_on` la fuerza.

### 4. Renderizar (opcional)

```bash
if command -v dot >/dev/null 2>&1; then
  dot -Tsvg graph-apply.dot                > graph-apply.svg
  dot -Tsvg graph-apply-with-depends.dot   > graph-apply-with-depends.svg
  echo "SVG generados en $(pwd)."
else
  echo "SKIP: 'dot' no instalado. Lee los .dot a mano."
fi
```

## Preguntas

1. ¿Qué pasaría con el grafo si `random_integer.port` *no* referenciara a `random_pet.name` ni usara `depends_on`? ¿Por qué?
2. ¿Qué nodos aparecen en `graph-apply.dot` que *no* son recursos de usuario?
3. Si `local_file.report` tuviera `for_each`, ¿cómo cambiaría la cantidad de nodos?

## Limpieza

```bash
cd / && rm -rf /tmp/tf-10-ex01
```
