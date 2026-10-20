# Consumer stack. Pins the golden module by SemVer tag.
# The registry here is a bare git repo at /tmp/registry/local-greeter.git.
module "hello_platform" {
  source = "git::file:///tmp/registry/local-greeter.git?ref=v1.0.0"

  name       = "hello-platform"
  owner      = "team-platform"
  message    = "Hello from a consumer stack"
  output_dir = "/tmp/consumer-tf14-01/out"
}

output "greeting_path" {
  value = module.hello_platform.path
}
