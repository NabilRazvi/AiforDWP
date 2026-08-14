# Required Capstone Reflection

## 1. First instinct
The AI-generated diagnostic script treated C: as the operating-system disk when collecting free-space evidence.

## 2. Why it initially seemed plausible
Many Windows endpoints use C: for the operating system, so this looked like a quick and reasonable default during first-pass scripting.

## 3. Evidence or review finding that did not support it
In the script review, Section 4 states this was corrected because the requirement was free space on the OS disk, not always C:. The corrected script replaced the hard-coded C: check by reading the operating-system drive first and then querying that drive.

## 4. What changed in the analysis/script
The corrected script now gets the OS drive dynamically and calculates free-space values from that drive. It also guards the free-space percentage calculation for unexpected disk metadata.

## 5. Lesson for future AI-assisted incident work
Do not accept common-environment defaults as facts. For incident evidence collection, map every check to the exact requirement and remove hidden assumptions before using output to support or reject hypotheses.