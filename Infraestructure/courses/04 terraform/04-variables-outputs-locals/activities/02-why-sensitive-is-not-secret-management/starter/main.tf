resource "tls_private_key" "demo" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# ⚠️ VALOR DUMMY — NO es un secreto real. Lo marcamos con un prefijo único
# para poder localizarlo con grep en el terraform.tfstate.
resource "random_pet" "dummy_token" {
  length    = 3
  separator = "_"
  prefix    = "DUMMY-SECRET-DO-NOT-USE-"
}
