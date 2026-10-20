package main

test_denies_privileged if {
	some msg in deny with input as {
		"kind": "Pod",
		"metadata": {"name": "bad"},
		"spec": {"containers": [{"name": "c", "image": "nginx:1.27", "securityContext": {"privileged": true}}]},
	}
	contains(msg, "privileged")
}

test_denies_hostpath if {
	some msg in deny with input as {
		"kind": "Pod",
		"metadata": {"name": "bad"},
		"spec": {
			"containers": [{"name": "c", "image": "nginx:1.27"}],
			"volumes": [
				{"name": "data", "emptyDir": {}},
				{"name": "root", "hostPath": {"path": "/"}},
			],
		},
	}
	contains(msg, "hostPath")
}

test_allows_clean_pod if {
	not deny_any with input as {
		"kind": "Pod",
		"metadata": {"name": "good"},
		"spec": {"containers": [{"name": "c", "image": "nginx:1.27"}]},
	}
}

deny_any if {
	some _ in deny
}
