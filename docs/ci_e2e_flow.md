# OTOMATİK KODLAMA — E2E/CI Veri Akışı

```mermaid
flowchart LR
  A[tasks_template.csv] -->|build-tasks.js| B(build/tasks.json)
  B --> C{{Playwright E2E}}
  subgraph Rules
    R1[Visual Gate (design_ref + threshold)]
    R2[Text Coverage ≥ %90]
  end
  C -->|PASS| D[CI Status ✓]
  C -->|FAIL| E[Quarantine Reporter]
  E --> F[quarantine.json]
  E --> G[ai_queue/failed_tests.jsonl]
  G --> H[(OpenAI Summary / PR Comment)]
  C -.-> R1
  C -.-> R2

  %% subgraph kimliği sade tutuldu, başlık köşeli parantezde
  subgraph CICD [CI/CD]
    I[GitHub Actions]
    I --> C
    I --> J[Artifacts: playwright-report, ai_queue]
  end