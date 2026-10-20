package main

# Pinned images: ninguna imagen puede llevar tag :latest ni venir sin tag.
# Idealmente debe venir anclada por digest (sha256:...), pero empezamos
# bloqueando lo mas peligroso.

pod_spec := input.spec if input.kind == "Pod"

pod_spec := input.spec.template.spec if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet"}
}

deny contains msg if {
	some c in pod_spec.containers
	endswith(c.image, ":latest")
	msg := sprintf("container %q uses :latest tag in %s/%s", [c.name, input.kind, input.metadata.name])
}

deny contains msg if {
	some c in pod_spec.containers
	not contains(c.image, ":")
	not contains(c.image, "@sha256:")
	msg := sprintf("container %q in %s/%s has no tag or digest (floating)", [c.name, input.kind, input.metadata.name])
}
