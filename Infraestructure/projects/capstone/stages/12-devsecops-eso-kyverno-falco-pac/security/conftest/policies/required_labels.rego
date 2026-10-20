package main

# Required ownership labels: shift-left mirror de la ClusterPolicy
# `require-ownership-labels`. Si el manifiesto no trae las tres labels,
# conftest lo rechaza antes de que llegue a admisión.

required_labels := {
	"app.kubernetes.io/name",
	"app.kubernetes.io/owner",
	"app.kubernetes.io/env",
}

targets := {"Deployment", "Pod", "StatefulSet", "DaemonSet"}

deny contains msg if {
	input.kind in targets
	some label in required_labels
	not input.metadata.labels[label]
	msg := sprintf("%s/%s is missing required label %q", [input.kind, input.metadata.name, label])
}
