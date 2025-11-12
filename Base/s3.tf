# This bucket is sued to store secrets for ECS

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.cluster_name}"

  tags = {
    Name        = "Usage"
    Environment = "ECS Bucket related"
  }
}

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::161805785056:role/Github-OIDC-Full-Access"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}