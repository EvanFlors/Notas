// good.tf — should PASS CKV_ACME_1
resource "aws_s3_bucket" "ok" {
  bucket = "acme-good-bucket"
  tags = {
    data_classification = "internal"
    owner               = "data-platform"
  }
}
