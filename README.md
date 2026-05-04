# GraphQL + OTel → Elastic Observability Demo

Demonstrates Elastic Observability capturing traces, metrics, and spans from a
GraphQL application instrumented with OpenTelemetry.

## Stack

| Layer | Technology |
|---|---|
| API | Node.js, Apollo Server 4 |
| OTel | `@opentelemetry/sdk-node`, `instrumentation-graphql`, OTLP/gRPC exporter |
| Database | PostgreSQL 16 |
| Observability | Elastic Cloud Serverless Observability (APM + metrics) |
| Infrastructure | Azure VM (Ubuntu 24.04), provisioned with Terraform |

## Live endpoints (after `terraform apply`)

| | URL |
|---|---|
| Blog | `http://<vm_ip>:4000/` |
| GraphQL Sandbox | `http://<vm_ip>:4000/graphql` |

`vm_ip` is printed as `vm_public_ip` in Terraform outputs.

## Sample query for the Sandbox

Paste this into the Apollo Sandbox at `/graphql`. It fetches a post with its
author and all comments (each with their author), triggering a chain of nested
resolver calls that appear as individual spans in Elastic APM.

```graphql
query PostWithDetails {
  post(id: "1") {
    id
    title
    content
    publishedAt
    author {
      name
      email
    }
    comments {
      body
      author {
        name
      }
    }
  }
}
```

**What you see in Kibana → Observability → APM → Services → graphql-blog:**

- Transaction name: `query PostWithDetails`
- Child spans: `post` → `post.author`, `post.comments`, then one `post.comments.author`
  span per comment (visible N+1 pattern)
- Span attributes include the GraphQL field path and operation type

## Deploy

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# EC_API_KEY must be set in the environment
export EC_API_KEY="..."
cd terraform && terraform init && terraform apply
```

See `config/README.md` for OTel configuration details.

## Generate load

```bash
scripts/generate-load.sh --count 20 --delay 0.5
```

Sends a mix of list queries, detail queries, and mutations. Traces appear in
Kibana within 30–60 seconds of the first request.

## Teardown

```bash
cd terraform && terraform destroy
# or: az group delete --name rg-graphql-otel
```
