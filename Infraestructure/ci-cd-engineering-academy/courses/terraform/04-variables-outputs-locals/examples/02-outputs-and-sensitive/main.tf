# Genera una llave privada TLS self-signed. El PEM privado es, por naturaleza,
# un secreto; lo usamos aquí para demostrar que `sensitive = true` NO lo protege
# dentro del state.
resource "tls_private_key" "demo" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Un identificador dummy. NO es un secreto real; es una cadena marcada para que
# puedas verla con `grep` en el state y comprobar que `sensitive` no la cifra.
# ⚠️ VALOR DUMMY — NUNCA uses esto como secreto real.
resource "random_pet" "dummy_key_id" {
  length    = 2
  separator = "_"
  prefix    = "fake-token-NOT-A-REAL-SECRET"
}
