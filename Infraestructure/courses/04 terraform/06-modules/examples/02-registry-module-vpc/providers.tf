# Solo el root configura providers "de verdad".
# Para init+validate NO hace falta región ni credenciales; para plan/apply sí.
provider "aws" {
  region = "us-east-1"
}
