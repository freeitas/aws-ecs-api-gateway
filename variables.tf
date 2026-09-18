
variable "region" {
  description = "The AWS region where the resources will be created. Defaults to us-east-1."
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project. Used to tag resources and provide a common identifier."
  type        = string
}

variable "vpc_link" {
  description = "Identifier of the VPC Link used to connect resources, such as API Gateway to services inside a VPC."
  type        = string
}

variable "environment" {
  description = "The environment the resources will be deployed to, such as dev, staging or prod."
  type        = string
}

variable "dns_name" {
  description = "DNS name to be used for the service. It is associated with Route 53 for domain mapping."
  type        = string
}

variable "route53_zone_id" {
  description = "ID of the Route 53 hosted zone where the DNS name will be created."
  type        = string
}

variable "base_mapping" {
  description = "Base path mapping used to route requests to the correct API in API Gateway."
  type        = string
}
