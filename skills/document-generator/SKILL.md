---
name: document-generator
description: "Generate PPTX, DOCX, XLSX documents with storytelling structure, visual layouts, and iterative HITL validation at each phase. Templates: 5-act, problem-solution, dashboard, metrics."
---

# Document Generator

## Overview

Generate professional documents (PowerPoint, Word, Excel) with storytelling structure,
diagrams, and iterative HITL validation. Every phase requires user approval before proceeding.

**Model strategy:** Opus for structure/storytelling decisions, Sonnet for content generation.

## Output Formats

| Format | Library | Use Case |
|--------|---------|----------|
| `pptx` | pptxgenjs | Presentations, meetings |
| `docx` | docx | Reports, proposals, documentation |
| `xlsx` | exceljs | Data reports, dashboards, metrics |

## Storytelling Templates

### PPTX Templates
| Template | Structure | Best For |
|----------|-----------|----------|
| `5-act` | POURQUOI > COMMENT > QUOI > PREUVE > REUTILISATION | Technical methodology |
| `problem-solution` | Problem > Impact > Solution > Results > CTA | Sales/proposals |
| `journey` | Status Quo > Challenge > Transformation > Success | Case studies |
| `technical` | Overview > Architecture > Implementation > Demo | Engineering |

### DOCX Templates
| Template | Structure | Best For |
|----------|-----------|----------|
| `executive` | Key Points > Data > Recommendations | C-level summary |
| `technical` | Overview > Architecture > Implementation > Demo | Engineering |

### XLSX Templates
| Template | Structure | Best For |
|----------|-----------|----------|
| `dashboard` | KPIs > Summary > Charts | Executive overview |
| `metrics` | Data tables > Trends > Analysis | Performance tracking |
| `financial` | Numbers > Formulas > Totals | Budget/costs |
| `export` | Raw data > Filters | Data extraction |
| `comparison` | Side-by-side > Variances | Analysis |

## Process (5 Phases with HITL)

### Phase 1: Discovery (HITL #1)

Use AskUserQuestion for each:
1. "What is the main topic?" (if not provided)
2. "Who is the target audience?" (Technical team / Management / Client / Mixed)
3. "What output format?" (PPTX / DOCX / XLSX)
4. "Which template?" (options based on format)
5. "Approximate size?" (slides/pages/sheets)

### Phase 2: Structure (HITL #2)

Generate an outline based on template. Examples:

**PPTX 5-Act:**
```
ACTE 1: POURQUOI — Title, Agenda, Context & Problem
ACTE 2: COMMENT — Methodology, Process Diagram, Key Steps
ACTE 3: QUOI — Deliverables, Technical Details, Data/Metrics
ACTE 4: PREUVE — Case Study, Results/Benchmarks
ACTE 5: REUTILISATION — Lessons Learned, Next Steps & CTA
```

**XLSX Dashboard:**
```
Sheet 1: Summary Dashboard (KPI Cards, Status)
Sheet 2: Detailed Metrics (Full table, auto-filter)
Sheet 3: Trends (Time series)
Sheet 4: Raw Data (Source data)
```

Use AskUserQuestion: "Does this outline work? Sections to add/remove/reorder?"

### Phase 3: Content (Iterative HITL)

For EACH section/slide/sheet, present proposed content and ask for validation.

For slides: Title, bullet content, visual description.
For XLSX sheets: define columns (key, header, width, type, format) + conditional formatting rules.

Use AskUserQuestion after each section: "Approve / Modify / Skip?"

### Phase 4: Diagram Generation (PPTX/DOCX)

When a section needs a diagram:
1. Write Mermaid definition
2. Show to user for validation via AskUserQuestion
3. Render to PNG
4. Include in document

### Phase 5: Generation

Generate the file using the appropriate library. Present final summary:

```
File: output/{document-name}.{ext}
Format: {FORMAT} ({count} slides/pages/sheets)
Contents: [summary of what was generated]
```

## Visual Defaults

| Element | PPTX | DOCX | XLSX |
|---------|------|------|------|
| Title font | Arial Black, 44pt | Calibri Bold, 24pt | Calibri Bold, 14pt |
| Body font | Arial, 18pt | Calibri, 11pt | Calibri, 11pt |
| Primary color | #1e3a5f | #1e3a5f | #1e3a5f |
| Accent | #73BF69 | #73BF69 | #73BF69 |

## XLSX Conditional Formatting

Available rules: color scales (Red > Green), data bars, icon sets (3Arrows, 3TrafficLights), cell rules (greaterThan, lessThan, equal).

## Safety Rules

1. **HITL at each phase** — never skip user validation
2. **Visual-First for PPTX** — at least 50% visual slides
3. **No consecutive same category** — max 3 similar slides in a row
