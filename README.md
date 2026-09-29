# aws_route53_record-cached-reads-demo

A demo of the experimental "cached read" feature for the `aws_route53_record` Terraform resource.

This feature was a [community submission](https://github.com/hashicorp/terraform-provider-aws/pull/48525) to the AWS provider, set for release in `v6.67.0`.

## Running the Demo

The demo is intended to showcase how the current design of `aws_route53_record` can trigger request throttling in workspaces with many managed records in a single hosted zone. To compare the default behavior against the experimental read cache, an existing hosted zone and set of records must be provisioned.

```shell
terraform init
```

```shell
terraform apply
```

Once in place, compare the behavior of a standard `terraform plan` against a `make plan` (local provider build needed until `v6.67.0` is released) with `TF_AWS_ROUTE53_RECORD_BATCH_READS=1` set.

```shell
# in quiet accounts, this may need to run multiple times
# to trigger throttling + retry backoff in the provider
terraform plan
```

```shell
# this should be fast
TF_AWS_ROUTE53_RECORD_BATCH_READS=1 make plan
```

## Viewing the Slides

Requires [`slides`](https://github.com/maaslalani/slides) to be installed.

```shell
slides SLIDES.md
```
