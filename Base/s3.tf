# This bucket is sued to store secrets for ECS

resource "aws_s3_bucket" "bucket" {
  count = var.secrets_s3_bucket.enable_secrets_bucket ? 1 : 0
  bucket = "${var.secrets_s3_bucket.bucket_name}"

  tags = {
    Name        = "Usage"
    Environment = "ECS Bucket related"
  }
}

resource "aws_s3_bucket_policy" "allow_access" {
  count = var.secrets_s3_bucket.enable_secrets_bucket ? 1 : 0
  bucket = aws_s3_bucket.bucket[count.index].id
  policy = data.aws_iam_policy_document.allow_access[count.index].json
}

data "aws_iam_policy_document" "allow_access" {
count = var.secrets_s3_bucket.enable_secrets_bucket ? 1 : 0
  statement {
    principals {
      type        = "AWS"
      identifiers = ["${var.secrets_s3_bucket.identifiers}"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.bucket[0].arn,
      "${aws_s3_bucket.bucket[0].arn}/*",
    ]
  }
}