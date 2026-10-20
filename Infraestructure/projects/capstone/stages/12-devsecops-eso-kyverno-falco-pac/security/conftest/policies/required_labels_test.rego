package main

test_denies_missing_labels if {
	some msg in deny with input as {
		"kind": "Deployment",
		"metadata": {"name": "bad", "labels": {"app.kubernetes.io/name": "x"}},
		"spec": {"template": {"spec": {"containers": [{"name": "c", "image": "nginx:1.27"}]}}},
	}
	contains(msg, "owner")
}

test_allows_all_labels if {
	not deny_any with input as {
		"kind": "Deployment",
		"metadata": {
			"name": "good",
			"labels": {
				"app.kubernetes.io/name": "x",
				"app.kubernetes.io/owner": "y",
				"app.kubernetes.io/env": "dev",
			},
		},
		"spec": {"template": {"spec": {"containers": [{"name": "c", "image": "nginx:1.27"}]}}},
	}
}

deny_any if {
	some _ in deny
}
