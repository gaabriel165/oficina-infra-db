# oficina-infra-db — Banco de Dados Gerenciado (Terraform)

[![Terraform](https://github.com/gaabriel165/oficina-infra-db/actions/workflows/terraform.yml/badge.svg)](https://github.com/gaabriel165/oficina-infra-db/actions/workflows/terraform.yml)

Provisiona, com **Terraform**, o banco **Amazon RDS for PostgreSQL** do microsserviço de ordens de serviço ([oficina-os-service](https://github.com/gaabriel165/oficina-os-service)). Depende da rede criada por [oficina-infra-k8s](https://github.com/gaabriel165/oficina-infra-k8s), lida via `terraform_remote_state`, e publica a string de conexão no **SSM Parameter Store** para que o pipeline do serviço nunca precise de segredos manuais.

Parte do Tech Challenge da pós-graduação em Arquitetura de Software (FIAP SOAT) — Fases 3 e 4. A justificativa formal do PostgreSQL, o diagrama ER e a explicação do modelo relacional estão em [`oficina-os-service/docs/architecture/database.md`](https://github.com/gaabriel165/oficina-os-service/blob/main/docs/architecture/database.md).

Na Fase 4 cada microsserviço passou a ter o próprio banco. Este repositório guarda só o banco do OS Service; o RDS do Billing Service e as tabelas DynamoDB do Execution Service são criados pelo Terraform de cada um deles. A Lambda de autenticação deixou de acessar o banco e consulta o cliente pela API do OS Service.

## Propósito

- Banco relacional **gerenciado** (backups automáticos, criptografia em repouso, patching) para o OS Service.
- Acesso **apenas de dentro da VPC**: o security group aceita 5432 só do security group dos nós do EKS.
- Senha gerada pelo Terraform (`random_password`) e entregue via SSM SecureString `/oficina-api/database_url`; nada em texto plano no Git.
- Visibilidade: Performance Insights, export de logs do PostgreSQL para o CloudWatch e `log_min_duration_statement = 500 ms` para achar consultas lentas.

## Tecnologias

| Categoria | Tecnologias |
|---|---|
| IaC | Terraform ≥ 1.10, provider AWS 5.x, provider random |
| Banco | Amazon RDS for PostgreSQL 16.15, `db.t3.micro`, gp3 20 GiB criptografado, single-AZ |
| Segurança | Security groups dedicados, sem acesso público, SSM SecureString |
| State | S3 `oficina-api-terraform-state-728750563430`, key `db/terraform.tfstate`, lock nativo |
| CI/CD | GitHub Actions — `fmt`/`validate`/`plan` no PR, `apply` no merge em `main`, `destroy` por `workflow_dispatch` |

## Arquitetura deste repositório

```mermaid
flowchart LR
    subgraph GitHub["GitHub - oficina-infra-db"]
        PR["Pull Request"] --> Plan["terraform fmt, validate, plan"]
        Main["branch main"] --> Apply["terraform apply"]
    end

    S3k[("S3 state - k8s/")]
    S3d[("S3 state - db/")]

    subgraph AWS["AWS us-east-1"]
        subgraph VPC["VPC - subnets privadas"]
            RDS[("RDS PostgreSQL 16.15 db.t3.micro<br/>gp3 20GB criptografado, backup 1 dia")]
            SGdb["SG db: 5432 apenas do SG dos nós EKS"]
            PG["Parameter group: log_min_duration_statement 500"]
        end
        SSM[("SSM: /oficina-api/database_url")]
        CW["CloudWatch: logs postgresql, Performance Insights"]
    end

    Apply -.->|"lê vpc, subnets, SG dos nós"| S3k
    Apply -.-> S3d
    Apply --> RDS
    Apply --> SGdb
    Apply --> PG
    Apply --> SSM
    RDS -.-> CW
    SSM -.->|"lido pelo CD"| Consumers["oficina-os-service"]
```

### Recursos criados

| Arquivo | Recursos |
|---|---|
| `remote-state.tf` | Lê `vpc_id`, `private_subnet_ids` e `node_security_group_id` do state `k8s/` |
| `rds.tf` | `aws_db_subnet_group` (subnets privadas), `aws_security_group.db` (5432 dos nós EKS), `aws_db_parameter_group` (postgres16, `log_min_duration_statement=500`), `aws_db_instance` |
| `ssm.tf` | SSM SecureString `/oficina-api/database_url` = `postgres://user:pass@host:5432/oficina_mecanica?sslmode=require` |
| `outputs.tf` | `rds_endpoint`, `db_name`, `db_security_group_id`, `database_url_parameter_name`, `database_url` (sensível) |

### Quem consome

| Consumidor | Como |
|---|---|
| `oficina-os-service` (CD) | `aws ssm get-parameter --name /oficina-api/database_url --with-decryption` → Secret do Kubernetes |

O schema (tabelas, índices, seed) é versionado com **golang-migrate** no repositório da aplicação e aplicado no startup dela ([ADR-008](https://github.com/gaabriel165/oficina-os-service/blob/main/docs/architecture/adr/ADR-008-migrations-no-startup-da-aplicacao.md)).

## Como executar

### Pré-requisitos

- `oficina-infra-k8s` já aplicado (a VPC e o security group dos nós precisam existir).
- AWS CLI autenticado e Terraform ≥ 1.10.

### Provisionar localmente

```bash
terraform init
terraform plan
terraform apply            # ~8 min (RDS)

terraform output rds_endpoint
terraform output -raw database_url     # sensível — só para depuração
```

### Acessar o banco de fora (opcional, para depuração)

O RDS não tem IP público. Uma opção é um pod `socat` no cluster + `kubectl port-forward`, conectando com `sslmode=require`.

### Deploy pelo pipeline

1. Pull Request → `fmt`, `validate` e comentário com o `plan`.
2. Merge em `main` → `terraform apply` automático.
3. `Actions → Terraform → Run workflow → destroy` remove o banco (sem snapshot final — ambiente de demonstração).

Configuração no GitHub (Settings → Secrets and variables → Actions):

| Tipo | Nome | Valor |
|---|---|---|
| Variable | `AWS_REGION` | `us-east-1` |
| Secret | `AWS_ROLE_ARN` | `arn:aws:iam::<conta>:role/oficina-api-db-infra-github-actions` (output `db_infra_github_actions_role_arn` do repo k8s) |

### Ordem entre os repositórios

```
oficina-infra-k8s  →  oficina-infra-db  →  CD dos três microsserviços  →  oficina-lambda-auth
```

Destruição na ordem inversa.

## Regras do repositório

- Branch `main` protegida: sem commits diretos, merge só por Pull Request com o workflow verde.
- `skip_final_snapshot = true` e `deletion_protection = false` são escolhas deliberadas para um ambiente **provisionado sob demanda** e destruído após cada sessão de testes. Em produção real, inverta ambos.

## Links

- Microsserviço dono do banco: [gaabriel165/oficina-os-service](https://github.com/gaabriel165/oficina-os-service)
- Swagger da API (com o ambiente no ar): `https://<api-id>.execute-api.us-east-1.amazonaws.com/swagger/index.html` · especificação versionada: [swagger.yaml](https://github.com/gaabriel165/oficina-os-service/blob/main/docs/swagger.yaml) · collection: [insomnia-collection.json](https://github.com/gaabriel165/oficina-os-service/blob/main/insomnia-collection.json)
- Rede e cluster: [gaabriel165/oficina-infra-k8s](https://github.com/gaabriel165/oficina-infra-k8s)
- Autenticação serverless + API Gateway: [gaabriel165/oficina-lambda-auth](https://github.com/gaabriel165/oficina-lambda-auth)
- Modelo de dados, justificativa e ER: [database.md](https://github.com/gaabriel165/oficina-api/blob/main/docs/architecture/database.md)
