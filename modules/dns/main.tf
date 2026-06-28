# Route53 hosted zone for the entire domain
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.project}-${var.environment}-zone"
  }
}

# ACM certificate for subdomain
resource "aws_acm_certificate" "main" {
  domain_name       = var.subdomain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.project}-${var.environment}-cert"
  }
}

# DNS validation record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# wait for acm certficate to be validated
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# A record aliasing subdomain to ELB
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.subdomain
  type    = "A"

  alias {
    name                   = var.elb_dns_name
    zone_id                = var.elb_zone_id
    evaluate_target_health = true
  }
}