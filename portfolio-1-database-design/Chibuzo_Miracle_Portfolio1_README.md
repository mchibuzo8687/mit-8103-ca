# Portfolio 1: Database Design and Modelling

**Course:** MIT 8103 Advanced Database Systems  
**Student:** Chibuzo Miracle  
**Student ID:** 301888687  
**Marks:** 7  
**Case study:** CareLink Clinic (multi-branch outpatient clinic)

## Deliverables

| File | Document type | Status |
|------|---------------|--------|
| [Chibuzo_Miracle_CaseStudy.md](Chibuzo_Miracle_CaseStudy.md) | Case study | Complete |
| [Chibuzo_Miracle_ERDiagram.md](Chibuzo_Miracle_ERDiagram.md) | ER diagram (Mermaid) + cardinality | Complete |
| [Chibuzo_Miracle_Schema.sql](Chibuzo_Miracle_Schema.sql) | Relational schema (PostgreSQL DDL) | Complete |
| [Chibuzo_Miracle_KeysConstraints.md](Chibuzo_Miracle_KeysConstraints.md) | Keys and constraints inventory | Complete |
| [Chibuzo_Miracle_Normalisation.md](Chibuzo_Miracle_Normalisation.md) | Normalisation to 3NF (BCNF notes) | Complete |
| Chibuzo_Miracle_Portfolio1_README.md (this file) | Portfolio guide | Complete |

## What This Portfolio Covers

1. Organisation / case study statement for CareLink Clinic  
2. Entity-Relationship model with cardinalities  
3. Relational schema with PKs, FKs, UNIQUE, CHECK, and indexes  
4. Keys and constraints mapped to business rules  
5. Normalisation justification through 3NF (with BCNF notes)

## How to Apply the Schema

```bash
psql -U postgres -d carelink -f Chibuzo_Miracle_Schema.sql
```

Or open the script in pgAdmin / DBeaver and execute against a PostgreSQL 14+ database.

## Suggested Review Order

1. Case study → understand users and operations  
2. ER diagram → entities and relationships  
3. Schema SQL → implementable design  
4. Keys/constraints → integrity rules  
5. Normalisation → why the design is in 3NF  
