terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {}

resource "aws_route53_zone" "test" {
  name          = "domain.test"
  force_destroy = true
}

resource "aws_route53_record" "test" {
  count = 80

  zone_id = aws_route53_zone.test.id

  name    = "demo-${count.index}"
  type    = "TXT"
  ttl     = 5
  records = ["foo", "bar"]
}
