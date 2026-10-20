"""Custom Checkov policy: every aws_s3_bucket must have a data_classification tag
whose value is in a well-known enum.

ID prefix CKV_ACME_* avoids colliding with built-in rules (CKV_AWS_*, CKV_K8S_*, ...).

If `checkov` is not installed, this file still imports cleanly for structural
validation; the real class only exists when checkov is importable.
"""

ALLOWED_CLASSIFICATIONS = {"public", "internal", "confidential", "restricted"}

try:
    from checkov.common.models.enums import CheckCategories, CheckResult
    from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

    class BucketMustHaveClassification(BaseResourceCheck):
        def __init__(self) -> None:
            super().__init__(
                name="S3 bucket must have data_classification tag with an allowed value",
                id="CKV_ACME_1",
                categories=[CheckCategories.CONVENTION],
                supported_resources=["aws_s3_bucket"],
            )

        def scan_resource_conf(self, conf):
            # Checkov typically hands us tags as [{"key": [value], ...}] (list wrapping)
            # OR as [{"key": value, ...}]. Handle both.
            raw_tags = conf.get("tags")
            if not raw_tags:
                return CheckResult.FAILED

            tags = raw_tags[0] if isinstance(raw_tags, list) else raw_tags
            if not isinstance(tags, dict):
                return CheckResult.FAILED

            classification = tags.get("data_classification")
            if classification is None:
                return CheckResult.FAILED

            # Unwrap single-element list if present.
            if isinstance(classification, list):
                if not classification:
                    return CheckResult.FAILED
                classification = classification[0]

            if not isinstance(classification, str) or not classification:
                return CheckResult.FAILED

            if classification not in ALLOWED_CLASSIFICATIONS:
                return CheckResult.FAILED

            return CheckResult.PASSED

    check = BucketMustHaveClassification()

except ImportError:
    # Checkov not installed. We expose only the enum so that structural tests
    # (and `python -c "import BucketMustHaveClassification"`) still succeed.
    check = None
