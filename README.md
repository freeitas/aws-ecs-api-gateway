# aws-ecs-api-gateway

API Gateway with a custom domain in front of ECS services, connected through a VPC Link.

## Architecture decisions

### Why REST API (v1) and not HTTP API (v2)
HTTP API is cheaper per request, but this API is metered: `api_keys.tf` creates an API key and a usage plan with a 100k/month quota and 1 rps per consumer, under the stage-wide 10 rps ceiling in `aws_api_gateway_method_settings` that shields the ECS tasks. The spec's `securitySchemes` binds that key to an `x-api-key` header. HTTP API has no native API keys or usage plans, and its private integrations need a v2 VPC Link rather than the v1 link this integration uses, so moving meant rebuilding metering as a Lambda authorizer plus a counter store.

### Why the OpenAPI file is the API, not HCL resources
There is not one `aws_api_gateway_resource` or `aws_api_gateway_method` here; `main.tf` builds the whole surface from `body = file(".../environment/${var.environment}/openapi.json")`. Declaring each path in HCL costs ~4 resources per endpoint and splits the contract I hand consumers from what is deployed. It also breaks redeploys: the `aws_api_gateway_deployment` trigger becomes a hand-maintained list of resource ids, and anything you forget gives the classic "apply succeeded, stage still serves the old routes". Here the trigger is `sha256(jsonencode(body))` — spec changed, stage redeployed, nothing to forget.

### Why the VPC Link id arrives as a stage variable
The integration points at `${stageVariables.vpcLinkId}`, and the stage fills it from the SSM parameter named by `var.vpc_link` (`/aws/ecs/vpc-link/id` in `environment/dev`). I refused to bake the id into the spec: another stack produces it and it changes whenever the VPC Link is replaced, so a network-side replacement would turn into an edit of every environment's `openapi.json`. Reading SSM instead of a `terraform_remote_state` data source also keeps this stack from needing read access to another stack's state file.

### Why REGIONAL endpoints and not edge-optimized
The API and the custom domain are both `REGIONAL`, the ACM certificate is issued in the provider's `var.region`, and Route 53 aliases `regional_domain_name`/`regional_zone_id`. Edge-optimized would front the API with a CloudFront distribution to create and propagate on every endpoint change, and pin the certificate to us-east-1 wherever the API runs. `POST /calculator` is computed per request against ECS in one region; there is nothing to cache at the edge.

### Why full data tracing and a one-day access log
`method_settings` logs at `INFO` with `data_trace_enabled = true` — without payloads, a failed VPC Link integration is an opaque 5xx. The access log format also captures `$context.responseBody`, `integrationStatus` and `$context.error.message`, and the request bodies here are personal health data (age, weight, height, gender). So the stage writes to a log group I declare in `clouwatch.tf`, capped at `retention_in_days = 1`, not one whose lifetime I do not control.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.69.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_api_gateway_api_key.fidelis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_api_key) | resource |
| [aws_api_gateway_base_path_mapping.v1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_base_path_mapping) | resource |
| [aws_api_gateway_deployment.health_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_domain_name.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_domain_name) | resource |
| [aws_api_gateway_method_settings.health_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_rest_api.health_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.health_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_api_gateway_usage_plan.fidelis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_usage_plan) | resource |
| [aws_api_gateway_usage_plan_key.fidelis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_usage_plan_key) | resource |
| [aws_cloudwatch_log_group.health_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_route53_record.cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_ssm_parameter.vpc_link](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base_mapping"></a> [base\_mapping](#input\_base\_mapping) | Base path mapping used to route requests to the correct API in API Gateway. | `string` | n/a | yes |
| <a name="input_dns_name"></a> [dns\_name](#input\_dns\_name) | DNS name to be used for the service. It is associated with Route 53 for domain mapping. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment the resources will be deployed to, such as dev, staging or prod. | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project. Used to tag resources and provide a common identifier. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where the resources will be created. Defaults to us-east-1. | `string` | `"us-east-1"` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | ID of the Route 53 hosted zone where the DNS name will be created. | `string` | n/a | yes |
| <a name="input_vpc_link"></a> [vpc\_link](#input\_vpc\_link) | Identifier of the VPC Link used to connect resources, such as API Gateway to services inside a VPC. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_health_api_invoke_url"></a> [health\_api\_invoke\_url](#output\_health\_api\_invoke\_url) | n/a |
<!-- END_TF_DOCS -->