package main

# No privileged containers, no hostPath, no hostNetwork. Equivalente shift-left
# del subset "privileged" del PSS. Vale para Pod directo y para PodSpec
# anidado en Deployment/StatefulSet/DaemonSet.

pod_spec := input.spec if input.kind == "Pod"

pod_spec := input.spec.template.spec if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet"}
}

deny contains msg if {
	some c in pod_spec.containers
	c.securityContext.privileged == true
	msg := sprintf("container %q in %s/%s is privileged", [c.name, input.kind, input.metadata.name])
}

deny contains msg if {
	pod_spec.hostNetwork == true
	msg := sprintf("%s/%s uses hostNetwork", [input.kind, input.metadata.name])
}

deny contains msg if {
	some v in pod_spec.volumes
	v.hostPath
	msg := sprintf("%s/%s mounts hostPath volume %q", [input.kind, input.metadata.name, v.name])
}
