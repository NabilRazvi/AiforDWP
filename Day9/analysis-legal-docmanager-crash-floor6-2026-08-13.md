# Incident Analysis and Root Cause Analysis (RCA): Legal Department Document Management Instability

**Date of analysis:** 2026-08-13  
**Incident date:** 2024-03-25  
**Analyst:** Digital Workplace Engineer  
**Department:** Legal (Floor 6)  
**Status:** Root cause assessed as highly likely, supported by multi-source evidence correlation

---

## 1) Executive Summary
At 10:15, Legal users on Floor 6 reported frequent crashes in the document management application, rendering it largely unusable for business operations. Correlated evidence from Nexthink DEX and SCCM shows a sharp deterioration beginning in the 10:00 window, shortly after a successful deployment of Legal Document Manager v2.1 at 09:44.

The most likely root cause is the v2.1 auto-save indexing behavior on low-memory devices (under 8 GB RAM), which aligns with vendor-known limitations and with observed high disk I/O and elevated crash rates. The deployment itself completed successfully from an SCCM delivery perspective; however, successful installation did not equate to runtime stability.

---

## 2) Scope, Severity, and Business Impact

### Scope
- Targeted endpoint group: Legal-Win11
- Total devices in scope: 45
- Hardware mix:
  - 8 GB RAM: 60% (27 devices)
  - 4 GB RAM: 40% (18 devices)
- Impacted application: `DocManager.exe` (top crash process during incident window)

### Severity Assessment
- Recommended classification: **SEV-2 (High)**
- Rationale:
  - Business-critical legal document workflow was degraded and intermittently unavailable.
  - Multi-user impact in a single department/floor.
  - No evidence of full enterprise outage, security compromise, or infrastructure-wide unavailability.

### Business Impact
- Legal document retrieval/editing interruptions.
- Reduced user productivity and increased ticket volume.
- Leadership visibility and escalation due to concentrated departmental outage characteristics.

---

## 3) Evidence Inventory

### Source A: Nexthink DEX (Legal-Win11)
| Date | Time | DEX Score | App Crash Rate | Disk I/O |
|---|---:|---:|---:|---|
| 2024-03-25 | 08:00 | 91 | 0.1% | Normal |
| 2024-03-25 | 09:00 | 90 | 0.2% | Normal |
| 2024-03-25 | 10:00 | 58 | 6.2% | High |
| 2024-03-25 | 11:00 | 55 | 6.8% | High |

Additional DEX fact:
- Top crashing process (10:00-11:00): `DocManager.exe` = 74% of all crashes in that window.

### Source B: SCCM Deployment Log
- 09:38:20: Deployment started (`Legal Document Manager v2.1`) to Legal-Win11 (45 devices)
- 09:44:07: Install completed, 45/45 devices
- 09:44:07: Install result: Success, 0 failures

Package context:
- Previous version: v2.0 (stable for 6 weeks)
- New version: v2.1
- Vendor known limitation: On devices with <8 GB RAM, auto-save indexing may cause high disk I/O and intermittent crashes during first hours post-install while initial index builds.

---

## 4) Timeline Reconstruction (Evidence-Based)

1. **08:00-09:00**
- Baseline healthy operating condition.
- DEX 90-91, crash rate 0.1-0.2%, disk I/O normal.

2. **09:38:20**
- SCCM starts deployment of v2.1 to all 45 Legal devices.

3. **09:44:07**
- SCCM reports deployment complete and successful on all devices.
- No SCCM install failures recorded.

4. **10:00 window**
- First major DEX degradation visible after deployment completion:
  - DEX drops from 90 to 58 (minus 32 points, ~35.6% decline from 09:00).
  - Crash rate rises from 0.2% to 6.2% (~31x increase).
  - Disk I/O changes from Normal to High.

5. **10:15**
- Floor 6 Legal users begin reporting frequent application crashes and unusable behavior.
- User reports align with DEX degradation already visible in the 10:00 interval.

6. **11:00 window**
- Degradation persists:
  - DEX remains low at 55.
  - Crash rate increases further to 6.8%.
  - Disk I/O remains High.

---

## 5) Correlation Analysis Across Data Sources

### Strong correlations observed
1. **Temporal correlation**
- Runtime degradation starts immediately after v2.1 deployment completion.

2. **Symptom correlation**
- User complaint: app crashes and unusable behavior.
- DEX confirms app crash spike and `DocManager.exe` dominance (74% of crashes).

3. **Resource-behavior correlation**
- High disk I/O begins in same period as crash spike.
- This matches vendor statement about initial indexing behavior.

4. **Hardware-risk correlation**
- 40% of Legal fleet has 4 GB RAM (<8 GB threshold named by vendor).
- Fleet composition includes a substantial at-risk subset.

### What this does and does not prove
- **Proven by evidence:**
  - Deployment succeeded technically (software distributed and installed).
  - Endpoint experience sharply worsened immediately post-deployment.
  - Crashes are concentrated in the newly deployed application process.
  - High disk I/O and crash pattern align with vendor-known behavior.

- **Not fully proven with current dataset:**
  - Exact per-device crash counts segmented by RAM tier (4 GB vs 8 GB).
  - Definitive exclusion of all other concurrent changes (none provided in dataset).

Conclusion on causality confidence:
- **High confidence probable causation**, not absolute proof, because the converging indicators across time, process, resource metrics, and vendor limitation are consistent and specific.

---

## 6) Root Cause and Contributing Factors

### Most Likely Root Cause
Post-deployment behavior of Legal Document Manager v2.1 auto-save indexing generated elevated disk I/O load, leading to instability and intermittent crashes of `DocManager.exe`, most notably on endpoints with under 8 GB RAM during initial post-install index build period.

### Contributing Factors
1. **Hardware heterogeneity risk in target fleet**
- 18 of 45 devices (40%) are below vendor-advised memory threshold.

2. **Big-bang deployment model**
- Simultaneous deployment to all 45 devices increased blast radius.

3. **Insufficient pre-production validation for low-memory cohort**
- No evidence of staged pilot targeting 4 GB RAM devices before full rollout.

4. **Monitoring/rollback gating gap**
- SCCM success criteria focused on install completion, not post-install runtime health KPIs.

---

## 7) Remediation Plan

### Immediate Actions (0-4 hours)
1. Pause further v2.1 promotion beyond Legal collection.
2. Prioritize rollback from v2.1 to v2.0 on the most impacted devices, starting with 4 GB RAM endpoints.
3. Communicate incident status and workaround guidance to Legal leadership and service desk.
4. Increase DEX monitoring frequency for Legal-Win11 (crash rate, DEX score, disk I/O) during mitigation.

### Short-Term Actions (same day to 72 hours)
1. Segment Legal-Win11 fleet by RAM tier and compare crash behavior per tier.
2. Run controlled validation:
- Cohort A: v2.1 on 8 GB devices
- Cohort B: v2.1 on 4 GB devices
- Measure crash rate and disk I/O for first 4 hours post-install.
3. Engage vendor with evidence package and request:
- Hotfix guidance or config to defer/throttle initial indexing
- Official compatibility statement for 4 GB endpoints
4. If rollback is not feasible for all devices, apply interim controls (for example index throttling if vendor-supported, staggered app launch windows).

### Long-Term Preventive Actions
1. Adopt phased deployment policy for business-critical apps:
- Pilot (5-10%) -> ringed rollout -> full deployment.
2. Add hardware-aware deployment gates in SCCM/CM collections (RAM-based targeting).
3. Define go/no-go criteria that combine delivery success and DEX health thresholds.
4. Update change management template to require vendor known-limitations review and explicit risk acceptance for low-spec devices.
5. Evaluate lifecycle plan to retire or uplift 4 GB endpoints in high-demand Legal workflows.

---

## 8) Validation Plan for Incident Closure
Incident can be considered stabilized when all criteria below are met for at least one full business day:
1. Legal-Win11 crash rate returns near pre-incident baseline (target <=0.5%).
2. DEX score recovers to acceptable range (target >=85).
3. Disk I/O trend returns from High to Normal on majority of fleet.
4. No new clustered Legal app-crash tickets during monitoring window.
5. `DocManager.exe` no longer dominates crash share abnormally.

---

## 9) Final RCA Statement
The incident was most likely caused by a functional-runtime regression introduced by Legal Document Manager v2.1, specifically its initial auto-save indexing process under low-memory conditions (<8 GB RAM), which drove high disk I/O and elevated `DocManager.exe` crashes immediately after fleet-wide deployment. SCCM confirms deployment execution success but does not contradict the runtime instability observed in Nexthink DEX. The combined evidence supports high-confidence probable causation with low residual uncertainty pending per-device RAM-tier crash segmentation.

---

## 10) Leadership Brief (Concise)
- **What happened:** Legal document app became unstable shortly after v2.1 deployment.
- **How bad:** High departmental impact (Floor 6 Legal), no enterprise-wide outage evidence.
- **Why likely:** Vendor-documented low-RAM indexing limitation matches DEX crash and high disk I/O spike.
- **What now:** Roll back impacted low-RAM devices first, validate by hardware cohort, then re-release via phased deployment only after runtime stability is proven.
