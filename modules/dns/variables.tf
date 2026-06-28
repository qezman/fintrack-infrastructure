variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "subdomain" {
  description = "Full subdomain for the app"
  type        = string
}

variable "elb_dns_name" {
  description = "ELB DNS name from ingress-nginx"
  type        = string
}

variable "elb_zone_id" {
  description = "ELB hosted zone ID"
  type        = string
}
