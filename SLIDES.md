---
author: Jared Baker
date: MMMM dd, YYYY
paging: Slide %d / %d
---

# Caching Shared Read Operations

An experiment with Terraform and Amazon Route53.

---

## Contents

1. Amazon Route53 and Terraform
1. Issue Timeline
1. Solutions
    1. `_exclusive` Resource (2025)
    1. **Caching Read Operations** (Today)

---

## Route53 Hosted Zones

Route53 is Amazon's managed DNS service.

- A **Hosted Zone** is a container for a single domain's DNS records.
- A **Record** represents a single entry in the Hosted Zone.

There are many [record types](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html), and a domain may have hundreds or thousands of records in a single zone.

---

## Route53 Terraform Resources

```hcl
resource "aws_route53_zone" "test" {
  name          = "domain.test"
  force_destroy = true
}

resource "aws_route53_record" "test" {
  zone_id = aws_route53_zone.test.id

  name    = "demo"
  type    = "TXT"
  ttl     = 5
  records = ["foo", "bar"]
}
```

All records are managed individually, following the Terraform [provider design principles](https://developer.hashicorp.com/terraform/plugin/best-practices/hashicorp-provider-design-principles#resources-should-represent-a-single-api-object).

> A Terraform resource should be a declarative representation of single component

---

## Reading Route53 Records

### APIs

- There is no `GetRecord` API
- `aws_route53_record` resources use the `ListResourceRecordSets` API and filter on the client-side
- Amazon [throttles](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/throttling-api-requests.html) API requests
  - Capacity is at the **account level**
  - Certain **operations** also have their own capacity

### Interaction with the `aws_route53_record` Resource Design

:(

---

## Issue Timeline

Complaints about this behavior are not new.

### Pre-1.0 Reports (2017-18)

- [December 2017](https://github.com/hashicorp/terraform-provider-aws/issues/2553) - Combine AWS API calls.
- [February 2018](https://github.com/hashicorp/terraform-provider-aws/issues/3230) - Aggregate multiple changes into a single request.

Community interest is low, and there are no home run solutions. These remain backlogged.

### AWS Escalation (2024)

- October 2024 - Meeting between AWS and HashiCorp to discuss customer issues with Terraform + Route53 at scale.
- [March 2025](https://github.com/hashicorp/terraform-provider-aws/pull/41741) - Release of `aws_route53_records_exclusive`.

### Community Proposal (Today)

- [September 2026](https://github.com/hashicorp/terraform-provider-aws/pull/48525) - Release of experimental read caching.

---

## 2024 Solution: `aws_route53_records_exclusive`

```hcl
resource "aws_route53_zone" "example" {
  name          = "example.com"
  force_destroy = true
}

resource "aws_route53_records_exclusive" "example" {
  zone_id = aws_route53_zone.example.zone_id

  resource_record_set {
    name = "subdomain.example.com"
    type = "A"
    ttl  = "30"
    # etc.
  }

  resource_record_set {
    name = "other-subdomain.example.com"
    # etc.
  }
}
```

---

## 2024 Solution: `aws_route53_records_exclusive`

### Pros

- Aggregates **both** Read and Write operations into a single* API request
- Familiar shape to the existing `aws_route53_record` resource
- Removes unconfigured "out-of-band" changes

### Cons

- [Cannot be used](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_records_exclusive) when multiple Terraform configurations manage records in the same Hosted Zone

---

## 2026 Solution: Caching Read Operations

Introduced last week, this experimental feature allows users to opt-in to caching read responses for the `aws_route53_record` resource.

### Pros

- The Read method now contains two branches: the pre-existing `List` call and a cache-based read
  - An environment variable, `TF_AWS_ROUTE53_RECORD_BATCH_READS` conditionally triggers the latter
- Fills a gap for Hosted Zones with multiple tenants

### Cons

- Does nothing for write operations

---

## 2026 Solution: Caching Read Operations

### Cache

- A package-local `tfsync.Map`, containing a "map of caches"
- Keyed by Hosted Zone (e.g. a read on one zone does not block another)
- A "get or load" cache function locks to ensure one writer

### Implementation

```go
// struct representing the cache for a single zone
type zoneRecordCache struct {
 mu       sync.RWMutex // to lock writes during cache load / apply-time updates
 loaded   bool         // to short circuit subsequent "load" function calls
 zoneName string
 records  map[string]awstypes.ResourceRecordSet // the cached values
}

// package-local, holds one cache per zone
var recordCacheZones tfsync.Map[string, *zoneRecordCache]
```

---

## 2026 Solution: Caching Read Operations

### Implementation (Cont.)

```go
func getOrLoadZoneRecordCache(ctx context.Context, conn *route53.Client, zoneID string) (*zoneRecordCache, error) {
 c, _ := recordCacheZones.LoadOrStore(zoneID, &zoneRecordCache{records: make(map[string]awstypes.ResourceRecordSet)})

 c.mu.Lock()
 defer c.mu.Unlock()

 if c.loaded {
  return c, nil
 }

 if err := c.load(ctx, conn, zoneID); err != nil {
  clear(c.records)
  return nil, err
 }
 c.loaded = true

 return c, nil
}
```

---

## 2026 Solution: Caching Read Operations

Demo 🙏

---

## Questions?
