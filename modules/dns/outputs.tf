output "nameservers" {
  description = "Route53 nameservers to set in Namecheap"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN for use with ELB/ingress"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}
