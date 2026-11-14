# CareLink Clinic — Cloud Deployment Evidence

**Document type:** CloudDeployment  
**Student:** Chibuzo Miracle (301888687)  
**File:** `Chibuzo_Miracle_CloudDeployment.md`  
**Case study:** CareLink Clinic  
**Note:** Snippets are academic deployment evidence (realistic configuration). No live cloud credentials are embedded.

## 1. Target cloud topology

| Component | Example service | Purpose |
|-----------|-----------------|---------|
| Primary + Multi-AZ standby | Amazon RDS for PostgreSQL 15 (Multi-AZ) **or** Azure Database for PostgreSQL Flexible Server (zone-redundant HA) | CareLink OLTP schema |
| Async read replica | RDS read replica in same region | History / analytics |
| Secrets | AWS Secrets Manager / Azure Key Vault | DB passwords, API keys |
| Connectivity | Private subnet + security group / NSG | Branch VPN or site-to-site to VPC |
| Optional documents | MongoDB Atlas M10+ replica set (same cloud region) | Portfolio 4 clinical notes |

**Region choice (illustrative):** prefer a region close to Lagos operations when available (e.g. `af-south-1` Cape Town) to reduce booking latency; otherwise a low-latency European region with private networking.

## 2. Local evidence — Docker Compose (primary + replica simulation)

Use this on a lab machine to demonstrate streaming replication topology analogous to cloud primary/replica, against the Portfolio 1 schema.

**File role:** runnable local evidence (save beside this markdown or paste into `docker-compose.yml` for demos).

```yaml
# Chibuzo_Miracle_CareLink_Compose.yml — local primary + replica simulation
# Student: Chibuzo Miracle (301888687)
# Usage (from this folder):
#   docker compose -f Chibuzo_Miracle_CareLink_Compose.yml up -d
#   # load schema into primary on port 5432, then verify replica on 5433

services:
  carelink-primary:
    image: postgres:15
    container_name: carelink-primary
    environment:
      POSTGRES_DB: carelink
      POSTGRES_USER: carelink_app
      POSTGRES_PASSWORD: change_me_lab_only
    ports:
      - "5432:5432"
    volumes:
      - carelink_primary_data:/var/lib/postgresql/data
      - ../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql:/docker-entrypoint-initdb.d/01_schema.sql:ro
    command:
      - postgres
      - -c
      - wal_level=replica
      - -c
      - max_wal_senders=10
      - -c
      - hot_standby=on
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U carelink_app -d carelink"]
      interval: 5s
      timeout: 5s
      retries: 10

  # Async replica stand-in: in production this is managed by RDS/Azure.
  # For a full physical replica lab, use pg_basebackup after primary is healthy.
  carelink-replica:
    image: postgres:15
    container_name: carelink-replica
    environment:
      POSTGRES_DB: carelink
      POSTGRES_USER: carelink_readonly
      POSTGRES_PASSWORD: change_me_lab_only
    ports:
      - "5433:5432"
    volumes:
      - carelink_replica_data:/var/lib/postgresql/data
    profiles:
      - full-replica-lab
    depends_on:
      carelink-primary:
        condition: service_healthy

volumes:
  carelink_primary_data:
  carelink_replica_data:
```

### 2.1 Load and smoke-check (primary)

```bash
# After compose is up (primary only is enough for schema evidence):
psql "postgresql://carelink_app:change_me_lab_only@localhost:5432/carelink" \
  -c "SELECT branch_code, name FROM branch ORDER BY branch_id;"

# Expect CL-IKE and CL-VI from Portfolio 1 seed.
```

### 2.2 Application connection guidance

```text
WRITE_DSN  = host=carelink-primary.xxxxx.rds.amazonaws.com dbname=carelink user=carelink_app sslmode=require
READ_DSN   = host=carelink-replica.xxxxx.rds.amazonaws.com dbname=carelink user=carelink_ro  sslmode=require

# CareLink API:
#  - booking / payment / encounter  → WRITE_DSN
#  - cross-branch history / reports → READ_DSN (fallback WRITE_DSN if lag alert)
```

## 3. Managed PostgreSQL — Terraform-style evidence (AWS RDS)

Pseudo-config illustrating Multi-AZ primary and one async read replica. Values are illustrative.

```hcl
# Chibuzo_Miracle_CareLink_RDS.tf — academic / illustrative Terraform
# Student: Chibuzo Miracle (301888687)
# Do NOT apply with real secrets in coursework repositories.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_subnet_group" "carelink" {
  name       = "carelink-db-subnets"
  subnet_ids = ["subnet-aaa", "subnet-bbb"] # private subnets in two AZs
}

resource "aws_db_instance" "carelink_primary" {
  identifier                 = "carelink-oltp"
  engine                     = "postgres"
  engine_version             = "15.4"
  instance_class             = "db.t3.medium"
  allocated_storage          = 100
  db_name                    = "carelink"
  username                   = "carelink_admin"
  password                   = var.db_password
  db_subnet_group_name       = aws_db_subnet_group.carelink.name
  multi_az                   = true          # sync standby in second AZ
  publicly_accessible        = false
  storage_encrypted          = true
  backup_retention_period    = 7
  deletion_protection        = true
  auto_minor_version_upgrade = true

  # Parameter group would set: synchronous_commit, max_connections, etc.
  tags = {
    Project = "CareLink"
    Student = "Chibuzo_Miracle_301888687"
    Tier    = "primary"
  }
}

resource "aws_db_instance" "carelink_read_replica" {
  identifier          = "carelink-oltp-read"
  replicate_source_db = aws_db_instance.carelink_primary.identifier
  instance_class      = "db.t3.medium"
  publicly_accessible = false
  storage_encrypted   = true

  tags = {
    Project = "CareLink"
    Tier    = "async-read-replica"
  }
}
```

### 3.1 Azure alternative (conceptual)

```text
Azure Database for PostgreSQL Flexible Server
  - High availability: Zone redundant
  - Read replica: same region (async)
  - Private access: VNet integration
  - Database: carelink
  - Deploy Portfolio 1 schema via CI migration job
```

## 4. Partitioning rollout on managed instance (ops evidence)

After schema load, a DBA migration (future change, documented here) can convert high-volume tables. Illustrative steps:

```sql
-- Documented migration sketch (NOT executed against Portfolio 1 source files)
-- 1) Create partitioned parent appointment_v2
-- 2) Attach partitions for branch_id IN (1), (2), DEFAULT
-- 3) Copy data from appointment
-- 4) Swap names in a maintenance window
-- 5) Recreate FKs from encounter / payment as required by PostgreSQL version
```

Day-to-day CareLink still uses the Portfolio 1 logical model; partitioning is a **storage/distribution** concern documented for Portfolio 5.

## 5. Failover behaviour (evidence checklist)

| Event | Expected CareLink behaviour | Evidence / control |
|-------|-----------------------------|--------------------|
| AZ A failure | RDS/Azure promotes standby; DNS endpoint updates | Multi-AZ = true / zone-redundant HA |
| Primary reboot (patch) | Brief connection errors; API retries idempotent booking | App retry with Portfolio 3 transaction boundaries |
| Replica unavailable | History falls back to primary | API READ_DSN failover logic |
| Region-wide outage | Clinic enters controlled offline mode | Runbook: no local multi-master writes |

### 5.1 RPO / RTO targets (academic)

| Metric | Target | Mechanism |
|--------|--------|-----------|
| RPO (data loss) | ≈ 0 for committed transactions | Sync multi-AZ standby |
| RTO (restore service) | Typically 1–2 minutes | Automated failover + connection retry |
| Replica lag SLO | &lt; 5s normal | CloudWatch / Azure metrics alert |

## 6. Security & compliance notes (clinic context)

- Encrypt storage at rest; require TLS (`sslmode=require`).  
- Branch sites reach the DB only via private networking / VPN — not public `5432`.  
- Least-privilege roles: `carelink_app` (DML), `carelink_ro` (SELECT on replica), admin separate.  
- Backups retained ≥ 7 days; test restore of `appointment` / `payment` quarterly.  
- Patient demographics are personal data: access logging and role separation remain mandatory even in distributed layout.

## 7. Optional MongoDB Atlas linkage (Portfolio 4)

```text
Atlas Project: CareLink-Notes
  Cluster: carelink-notes-rs (replica set, 3 nodes)
  Region: same as PostgreSQL for latency
  Collections: patient_timeline, encounter_notes
  Link keys: patient_id, encounter_id (from PostgreSQL)
  Consistency: eventual for note edits; PostgreSQL remains system of record for appointments & payments
```

## 8. Deployment evidence summary

| Artefact | Shows |
|----------|--------|
| Docker Compose primary (+ optional replica profile) | Local reproducible topology for schema load |
| Terraform RDS Multi-AZ + read replica | Cloud HA + read scale-out intent |
| Connection routing notes | Write vs read path for CareLink ops |
| Failover / RPO-RTO table | Availability story for clinic managers |
| Atlas note | Optional document tier without undermining CP booking |

Together these artefacts demonstrate a **realistic cloud deployment** for CareLink consistent with Portfolios 1–3, ready to extend toward Portfolio 4 NoSQL documents.
