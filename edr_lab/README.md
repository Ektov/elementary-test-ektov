# edr_lab — isolated multi-project Elementary experiment

- **DB**: `edr_lab` on `dbt_sandbox_postgres` (schema `elementary`)
- **Data**: full copy of `demo_db.elementary` + synthetic `domain_finance` rows
- **Runtime**: Docker image with `elementary-data[postgres]==0.25.1` only (no dbt project)

```bash
./edr_lab/run_report.sh
open edr_lab/edr_out/elementary_report.html
```

Host-side alternative (uses local `.venv2`):

```bash
edr report --profiles-dir edr_lab --profile-target lab_host --file-path edr_lab/edr_out/elementary_report.html
```
