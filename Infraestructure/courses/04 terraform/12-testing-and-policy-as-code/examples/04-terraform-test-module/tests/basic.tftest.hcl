run "plan_defaults" {
  command = plan

  assert {
    condition     = random_pet.this.length == 2
    error_message = "default length should be 2"
  }

  assert {
    condition     = random_pet.this.separator == "-"
    error_message = "separator should default to '-'"
  }
}

run "apply_short_name" {
  command = apply

  variables {
    length = 1
  }

  assert {
    condition     = output.pet_name != ""
    error_message = "pet_name output must be non-empty"
  }

  assert {
    condition     = length(split("-", output.pet_name)) == 1
    error_message = "with length=1 the pet name should have no separator"
  }
}
