// bad.tf — three buckets, all should FAIL CKV_ACME_1

// 1. No tags at all.
resource "aws_s3_bucket" "no_tags" {
  bucket = "acme-no-tags"
}

// 2. Tags present but no data_classification key.
resource "aws_s3_bucket" "wrong_tags" {
  bucket = "acme-wrong-tags"
  tags = {
    owner = "random-team"
  }
}

// 3. data_classification present but value not in enum.
resource "aws_s3_bucket" "weird_value" {
  bucket = "acme-weird-value"
  tags = {
    data_classification = "top-secret-handshake"
  }
}
