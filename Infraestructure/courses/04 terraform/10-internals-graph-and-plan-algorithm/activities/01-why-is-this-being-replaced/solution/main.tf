terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

# Fix: la función no determinista del starter reevaluaba cada plan
# y empujaba el bloque triggers a cambiar siempre, lo que forzaba
# replace en cada corrida. La intención original ("recrear si cambia
# la config de boot") se expresa con un valor determinista.
resource "null_resource" "boot" {
  triggers = {
    # Valor estable; recrea solo cuando cambia a mano.
    config = "default-boot-config-v1"
  }
}
