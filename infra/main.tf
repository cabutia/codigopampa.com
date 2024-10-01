provider "aws" {
  region = "sa-east-1" # Adjust based on your region
}

provider "aws" {
  alias  = "acm"
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "codigopampa-tf-backend" # S3 bucket for the Terraform state
    key    = "terraform.tfstate"
    region = "sa-east-1" # Adjust based on your region
  }
}

resource "aws_acm_certificate" "cert" {
  provider                  = aws.acm
  domain_name               = var.route53_domain
  subject_alternative_names = ["*.${var.route53_domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_record" {
  depends_on = [ aws_acm_certificate.cert ]
  zone_id = var.route53_zone_id

  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = "300"
}

resource "aws_acm_certificate_validation" "cert_validation" {
  depends_on = [ aws_acm_certificate.cert ]
  provider = aws.acm

  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_record : record.fqdn]
}

# S3 Bucket to hold the website
resource "aws_s3_bucket" "site" {
  bucket        = var.s3_bucket # Use a unique bucket name
  force_destroy = true
}

# S3 public policy
resource "aws_s3_bucket_policy" "s3_public_policy" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.s3_allow_public_access.json
}

# Policy
data "aws_iam_policy_document" "s3_allow_public_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]
    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*"
    ]
  }
}

# S3 website
resource "aws_s3_bucket_website_configuration" "s3_site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 Ownership
resource "aws_s3_bucket_ownership_controls" "s3_ownership" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 Access block
resource "aws_s3_bucket_public_access_block" "s3_accessblock" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 ACL
resource "aws_s3_bucket_acl" "s3_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.s3_ownership, aws_s3_bucket_public_access_block.s3_accessblock]

  bucket = aws_s3_bucket.site.id
  acl    = "public-read"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  depends_on = [aws_acm_certificate.cert]

  origin {
    domain_name = aws_s3_bucket_website_configuration.s3_site.website_endpoint
    origin_id   = "origin-${aws_s3_bucket_website_configuration.s3_site.website_endpoint}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }

    # s3_origin_config {
    #   origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    # }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["codigopampa.com", "*.codigopampa.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-${aws_s3_bucket_website_configuration.s3_site.website_endpoint}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access Identity for S3 Bucket"
}

# Route53 DNS Record
resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id # Add your Route53 zone ID here
  name    = var.route53_domain  # The domain or subdomain you want to point to CloudFront
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
