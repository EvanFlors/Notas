# STARTER — contiene errores intencionales. No borrar comentarios "FIX:".
#
# Objetivo: lograr `terraform validate` en Success, refactorizar count->for_each,
# agregar moved block, lifecycle y notas conceptuales.

# -----------------------------------------------------------------------------
# Antes se llamaba random_pet.application; el equipo lo renombró a random_pet.app
# sin agregar un `moved` block, así que el próximo plan destruiría y recrearía.
# FIX: agregar `moved { from = random_pet.application  to = random_pet.app }`.
# -----------------------------------------------------------------------------
resource "random_pet" "app" {
  length = 2
  prefix = var.name_prefix
}

# -----------------------------------------------------------------------------
# Usuarios ficticios como null_resource (simulan IAM users sin tocar cloud).
# FIX: pasar de count indexado por entero a for_each sobre map(object).
# Problema actual: insertar un usuario al inicio de la lista reindexa a todos
# y provoca destroy+create en cascada.
# -----------------------------------------------------------------------------
resource "null_resource" "aws_null_users" {
  count = length(var.users)

  triggers = {
    username = var.users[count.index]
    # FIX: no debería existir role aquí si users es list(string).
    role = "developer"
  }
}

# -----------------------------------------------------------------------------
# CA auto-firmada local — no toca cloud, no es secreto productivo, pero
# es un recurso cuya recreación invalidaría todo lo firmado por ella.
# FIX: agregar lifecycle { prevent_destroy = true } y comentar cuándo removerlo
# (rotación planificada con migración de los certificados firmados).
# -----------------------------------------------------------------------------
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.name_prefix}-ca"
    organization = "Example Academy"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# -----------------------------------------------------------------------------
# Dynamic block con reglas de ingress — compila pero tiene un error de atributo
# que rompe validate.
# FIX: `each.value` dentro de for_each sobre list requiere iterator. Usar for_each
# con `{ for r in var.ingress_rules : r.port => r }` o bien el iterator correcto.
# -----------------------------------------------------------------------------
resource "null_resource" "security_group_sim" {
  triggers = {
    rules_hash = jsonencode(var.ingress_rules)
  }

  # Este bloque intenta ilustrar `dynamic`; la sintaxis actual es incorrecta.
  # dynamic "ingress" {
  #   for_each = var.ingress_rules
  #   content {
  #     port        = each.value.port
  #     protocol    = each.value.protocol
  #     description = each.value.description
  #   }
  # }
}

# -----------------------------------------------------------------------------
# Lifecycle MAL puesto: fuerza replace en cada plan por un atributo que
# cambia solo (random). FIX: remover replace_triggered_by o apuntarlo a algo
# estable.
# -----------------------------------------------------------------------------
resource "null_resource" "broken_lifecycle" {
  triggers = {
    always_new = timestamp()
  }

  lifecycle {
    replace_triggered_by = [null_resource.broken_lifecycle.triggers]
  }
}

# NOTAS
# -----
# TODO (estudiante): completar al terminar el refactor.
# - for_each vs count aquí: ...
# - prevent_destroy garantiza / no garantiza: ...
# - sensitive en output garantiza / no garantiza: ...
