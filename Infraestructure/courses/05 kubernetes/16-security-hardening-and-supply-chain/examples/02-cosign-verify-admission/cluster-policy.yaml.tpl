apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images-cosign
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signed-images
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [app]
      verifyImages:
        - imageReferences:
            - "localhost:5001/app/*"
          mutateDigest: true
          verifyDigest: true
          required: true
          attestors:
            - entries:
                - keys:
                    publicKeys: |
__COSIGN_PUBKEY__
                    rekor:
                      ignoreTlog: true
