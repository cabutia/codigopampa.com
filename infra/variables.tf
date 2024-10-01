variable "s3_bucket" {
  type        = string
  description = "The S3 where the site lives at."
}

variable "route53_zone_id" {
  type        = string
  description = "The hosted zone ID"
}

variable "route53_domain" {
  type        = string
  description = "The application domain"
}