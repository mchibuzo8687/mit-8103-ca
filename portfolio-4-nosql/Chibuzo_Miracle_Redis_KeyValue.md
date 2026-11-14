# CareLink Clinic — Redis Key–Value Patterns

**Document type:** Redis_KeyValue  
**Student:** Chibuzo Miracle (301888687)  
**File:** `Chibuzo_Miracle_Redis_KeyValue.md`  
**Course:** MIT 8103 — Portfolio 4 (NoSQL)  
**Complements:** PostgreSQL appointments (Portfolio 1) and concurrency holds (Portfolio 3)

## 1. Role of Redis in CareLink

Redis is used as a **key–value / in-memory coordination store**, not as the permanent appointment ledger. PostgreSQL remains authoritative for:

- `appointment` rows and `UNIQUE (doctor_id, scheduled_at)`
- payment records
- staff and branch master data

Redis accelerates:

1. Slot availability checks for reception calendars  
2. Short-lived **holds** while a booking is confirmed  
3. Staff **sessions** after login  
4. Same-day **check-in** flags at the branch desk  

Business keys reuse Portfolio 1 codes (`CL-IKE`, `DOC-001`, appointment ids).

---

## 2. Key design

| Pattern | Redis type | Example key | Value / members | TTL |
|---------|------------|-------------|-----------------|-----|
| Slot occupancy | String | `slot:CL-IKE:DOC-001:202603151030` | `booked` \| `held` \| `free` | none for booked; short for held |
| Doctor-day booked set | Set | `doctor:day:DOC-001:20260315` | `1030`, `1100`, … | end of clinic day optional |
| Booking hold | Hash | `hold:HLD-9f3a` | patientNumber, staffNumber, branchCode, slot | 5–10 minutes |
| Staff session | Hash | `session:staff:TOK-ada-01` | staffNumber, role, branchId | 8 hours |
| Check-in | String | `checkin:101` | `arrived` / desk code | 4 hours |

Time fragments use local clinic wall-clock `yyyyMMddHHmm` so keys stay human-debuggable for operations staff.

---

## 3. Sample command script (redis-cli)

```redis
# --- Seed: mark afternoon slots for Dr Ada Okeke (DOC-001) at Ikeja ---
SET slot:CL-IKE:DOC-001:202603151030 booked
SET slot:CL-IKE:DOC-001:202603151100 free
SET slot:CL-IKE:DOC-001:202603151130 free
SADD doctor:day:DOC-001:20260315 1030

# --- Reception starts a hold for PAT-1001 at 11:00 ---
HSET hold:HLD-9f3a patientNumber PAT-1001 staffNumber DOC-001 branchCode CL-IKE slot 202603151100
EXPIRE hold:HLD-9f3a 600
SET slot:CL-IKE:DOC-001:202603151100 held EX 600

# --- After PostgreSQL INSERT appointment succeeds, promote hold to booked ---
SET slot:CL-IKE:DOC-001:202603151100 booked
SADD doctor:day:DOC-001:20260315 1100
DEL hold:HLD-9f3a

# --- Staff session (DOC-001) ---
HSET session:staff:TOK-ada-01 staffNumber DOC-001 role doctor branchCode CL-IKE
EXPIRE session:staff:TOK-ada-01 28800

# --- Patient check-in for appointment_id 101 ---
SET checkin:101 arrived EX 14400

# --- Calendar paint: is 11:30 free? ---
GET slot:CL-IKE:DOC-001:202603151130

# --- List booked minutes for the doctor-day ---
SMEMBERS doctor:day:DOC-001:20260315
```

### Hold release (abandoned booking)

```redis
# TTL expiry auto-clears held slot if EX was set on the slot key.
# Explicit cancel path:
GET hold:HLD-9f3a
DEL hold:HLD-9f3a
SET slot:CL-IKE:DOC-001:202603151100 free
```

---

## 4. Mapping to CareLink operations

| Operation (case study) | Redis involvement | Still committed in PostgreSQL? |
|------------------------|-------------------|--------------------------------|
| Book appointment | Check/set slot; create hold | Yes — final `appointment` insert |
| Cancel / no-show | Delete or rewrite slot key; `SREM` doctor-day | Yes — status update |
| Check in patient | `SET checkin:{id}` | Optional status `checked_in` |
| Staff login | Session hash + TTL | Auth credentials not stored here |
| Retrieve history | Not primary | MongoDB documents / SQL joins |

---

## 5. Suitability vs relational

| Strength of Redis | Limitation |
|-------------------|------------|
| Sub-millisecond slot reads under reception load | Data volatility — rebuild from SQL after flush |
| TTL naturally expires abandoned holds | No rich clinical query language |
| Simple key patterns easy to reason about | Multi-key atomicity needs `MULTI/EXEC` or Lua for complex flows |
| Complements Portfolio 3 concurrency story | Must not replace unique booking constraint in PostgreSQL |

**Judgment:** Redis is appropriate for CareLink’s **hot path scheduling and session** concerns. Clinical notes and payments do not belong in key–value storage.

---

## 6. Rebuild sketch after cache miss

Pseudocode (application layer):

```text
for each appointment where status in ('booked','checked_in')
    and scheduled_at::date = today:
        SET slot:{branchCode}:{staffNumber}:{yyyyMMddHHmm} booked
        SADD doctor:day:{staffNumber}:{yyyyMMdd} {HHmm}
```

This keeps Redis a disposable performance layer while Portfolio 1 remains the source of truth.
