# Stack intencionalmente roto para la actividad tf-02-02.
# Hay 3 errores aqui + 1 en providers.tf. Total: 4.
# NO cambies los nombres de los recursos ni los providers; solo corrige lo roto.

# ERROR 1 (tipo / schema): 'length' espera un numero, no un string.
resource "random_pet" "codename" {
  length    = "three"
  separator = "-"
}

# ERROR 2 (atributo desconocido): el atributo correcto es 'file_permission',
# NO 'permissons' (ademas con typo). Esto lo detecta 'terraform validate'.
resource "local_file" "badge" {
  filename    = "/tmp/tf-02-02-out/${random_pet.pet.id}.txt"
  content     = "soy ${random_pet.pet.id}\n"
  permissons  = "0644"
}

# ERROR 3 (referencia): el 'random_pet' se llama 'codename', NO 'pet'.
# Las referencias arriba en 'local_file.badge' usan el nombre incorrecto.
# Esto lo detecta 'terraform validate' como "Reference to undeclared resource".

output "badge_path" {
  value = local_file.badge.filename
}

output "codename" {
  value = random_pet.codename.id
}
