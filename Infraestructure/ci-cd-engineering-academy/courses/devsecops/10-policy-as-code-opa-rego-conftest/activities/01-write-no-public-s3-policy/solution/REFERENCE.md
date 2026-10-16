# REFERENCE — sec-10-01-write-no-public-s3-policy

> Modelo de referencia. **No es la única respuesta correcta** — es una contra la que compararte.

## `policy/s3.rego`

```rego
package terraform.s3

import rego.v1

# ---------------------------------------------------------------------
# Vector 1: ACL público en el bucket.
# ---------------------------------------------------------------------
deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_s3_bucket"
    r.values.acl in {"public-read", "public-read-write"}
    msg := sprintf(
        "S3 bucket %q has public ACL %q",
        [r.address, r.values.acl]
    )
}

# ---------------------------------------------------------------------
# Vector 2: aws_s3_bucket_public_access_block con algún flag en false.
# Los 4 flags: block_public_acls, block_public_policy,
# ignore_public_acls, restrict_public_buckets. Los 4 deben ser true.
# ---------------------------------------------------------------------
deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_s3_bucket_public_access_block"
    some flag in ["block_public_acls", "block_public_policy",
                  "ignore_public_acls", "restrict_public_buckets"]
    r.values[flag] == false
    msg := sprintf(
        "public_access_block %q has %s=false",
        [r.address, flag]
    )
}

# ---------------------------------------------------------------------
# Vector 3: bucket policy con Principal "*" sin Condition.
# El JSON de la policy aparece como string en terraform plan;
# aquí asumimos que ya se ha decodeado a input.values.policy_json
# (patrón común). Si llega como string, decodear antes con json.unmarshal.
# ---------------------------------------------------------------------
deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_s3_bucket_policy"
    some stmt in r.values.policy_json.Statement
    stmt.Effect == "Allow"
    stmt.Principal == "*"
    not stmt.Condition
    msg := sprintf(
        "bucket policy %q has Allow Principal=* without Condition",
        [r.address]
    )
}
```

## `policy/s3_test.rego`

```rego
package terraform.s3

import rego.v1

# ---------- Helpers ----------
_plan(resources) := {
    "planned_values": {"root_module": {"resources": resources}}
}

# ---------- Fixtures buenos ----------
test_allow_private_bucket if {
    plan := _plan([{
        "address": "aws_s3_bucket.ok",
        "type": "aws_s3_bucket",
        "values": {"acl": "private"}
    }])
    count(deny) == 0 with input as plan
}

# ---------- Fixtures malos ----------
test_deny_public_read_acl if {
    plan := _plan([{
        "address": "aws_s3_bucket.leak",
        "type": "aws_s3_bucket",
        "values": {"acl": "public-read"}
    }])
    some msg in deny with input as plan
    contains(msg, "public ACL")
}

test_deny_public_read_write_acl if {
    plan := _plan([{
        "address": "aws_s3_bucket.leak",
        "type": "aws_s3_bucket",
        "values": {"acl": "public-read-write"}
    }])
    count(deny) >= 1 with input as plan
}

test_deny_loose_public_access_block if {
    plan := _plan([{
        "address": "aws_s3_bucket_public_access_block.leak",
        "type": "aws_s3_bucket_public_access_block",
        "values": {
            "block_public_acls": true,
            "block_public_policy": false,   # <-- malo
            "ignore_public_acls": true,
            "restrict_public_buckets": true
        }
    }])
    some msg in deny with input as plan
    contains(msg, "block_public_policy=false")
}

test_deny_wildcard_principal_no_condition if {
    plan := _plan([{
        "address": "aws_s3_bucket_policy.leak",
        "type": "aws_s3_bucket_policy",
        "values": {
            "policy_json": {
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject"
                }]
            }
        }
    }])
    count(deny) >= 1 with input as plan
}
```

## Notas de diseño

1. **`package terraform.s3`** — un namespace por dominio hace que `conftest test --namespace terraform.s3` sea posible y mantiene las reglas separadas de `terraform.sg`, `terraform.iam`, etc.
2. **`import rego.v1`** es la sintaxis moderna (OPA ≥ 0.59); habilita `if`, `contains`, `every`, `in`.
3. **`not stmt.Condition`** aprovecha que acceder a un campo inexistente deja la expresión indefinida y `not undefined == true`. Es el mecanismo correcto para "este campo no está presente".
4. **El fixture del vector 3** asume policy ya como objeto. En un `terraform plan -json` real, `policy` llega como string JSON; en la regla real habría que:
   ```rego
   policy := json.unmarshal(r.values.policy)
   some stmt in policy.Statement
   ```
5. **Separación `warn` vs `deny`** — "versioning disabled" probablemente debería ser `warn` (deuda) y no `deny` (bloqueante). No se incluyó en el core para mantener el scope.

## Ejecución esperada

```bash
$ opa test -v policy/
data.terraform.s3.test_allow_private_bucket: PASS
data.terraform.s3.test_deny_public_read_acl: PASS
data.terraform.s3.test_deny_public_read_write_acl: PASS
data.terraform.s3.test_deny_loose_public_access_block: PASS
data.terraform.s3.test_deny_wildcard_principal_no_condition: PASS
--------------------------------------------------------------------------------
PASS: 5/5
```
