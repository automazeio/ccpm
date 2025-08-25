# NioPD Commands

This document is a complete reference for all commands available in the NioPD system.

## Table of Contents

- [Core Workflow Commands](#core-workflow-commands)
- [Advanced Discovery Commands](#advanced-discovery-commands)
- [Advanced Planning Commands](#advanced-planning-commands)
- [Advanced Launch Commands](#advanced-launch-commands)

---

## Core Workflow Commands

These are the fundamental commands for moving from an idea to a plan.

### `/niopd:new-initiative`
- **Purpose**: Start a new high-level product initiative.
- **Usage**: `/niopd:new-initiative "<initiative_name>"`
- **Output**: A new initiative file in `.iflow/data/initiatives/`.

### `/niopd:import-feedback`
- **Purpose**: Import a file of user feedback.
- **Usage**: `/niopd:import-feedback --from=<path> --for=<initiative>`
- **Output**: A copy of the feedback file in `.iflow/data/feedback-sources/`.

### `/niopd:summarize-feedback`
- **Purpose**: Analyze a feedback file and create a summary report.
- **Usage**: `/niopd:summarize-feedback --from=<file> --for=<initiative>`
- **Output**: A summary report in `.iflow/data/reports/`.

### `/niopd:draft-prd`
- **Purpose**: Automatically generate a PRD draft from an initiative and feedback.
- **Usage**: `/niopd:draft-prd --for=<initiative>`
- **Output**: A new PRD file in `.iflow/data/prds/`.

### `/niopd:edit-prd`
- **Purpose**: Get instructions to manually edit a PRD.
- **Usage**: `/niopd:edit-prd <prd_name>`
- **Output**: A message with the file path and instructions.

### `/niopd:update-roadmap`
- **Purpose**: Generate or update the product roadmap from all initiatives.
- **Usage**: `/niopd:update-roadmap`
- **Output**: A roadmap file in `.iflow/data/roadmaps/`.

---

## Advanced Discovery Commands

Commands to help with research, discovery, and understanding the market and users.

### `/niopd:analyze-competitor`
- **Purpose**: Analyzes a competitor's website for key features and positioning.
- **Usage**: `/niopd:analyze-competitor --url=<url>`
- **Output**: A competitor analysis report.

### `/niopd:summarize-interview`
- **Purpose**: Summarizes a user interview transcript, extracting key themes and quotes.
- **Usage**: `/niopd:summarize-interview --file=<path>`
- **Output**: An interview summary report.

### `/niopd:analyze-data`
- **Purpose**: Answers a natural language question about a structured data file (e.g., CSV).
- **Usage**: `/niopd:analyze-data --file=<path> --query="..."`
- **Output**: A data analysis report with the answer and methodology.

### `/niopd:generate-personas`
- **Purpose**: Creates user personas from a feedback summary.
- **Usage**: `/niopd:generate-personas --from=<summary_file>`
- **Output**: A document containing 2-3 user personas.

### `/niopd:research-trends`
- **Purpose**: Researches and summarizes market trends on a given topic using web search.
- **Usage**: `/niopd:research-trends --topic="..."`
- **Output**: A market trend report with key findings and sources.

---

## Advanced Planning Commands

Commands to assist with the details of planning and defining features.

### `/niopd:draw-diagram`
- **Purpose**: Creates a PlantUML or Mermaid diagram from a text description.
- **Usage**: `/niopd:draw-diagram --type=<type> --desc="..."`
- **Output**: A markdown file containing the diagram code.

### `/niopd:assess-feasibility`
- **Purpose**: Flags technically complex or risky requirements in a PRD.
- **Usage**: `/niopd:assess-feasibility --for=<prd_name>`
- **Output**: An assessment report.

### `/niopd:write-stories`
- **Purpose**: Writes detailed user stories and acceptance criteria for a PRD.
- **Usage**: `/niopd:write-stories --for=<prd_name>`
- **Output**: An updated PRD or a separate user story document.

### `/niopd:identify-risks`
- **Purpose**: Identifies potential market, technical, or dependency risks for an initiative.
- **Usage**: `/niopd:identify-risks --for=<initiative_name>`
- **Output**: A risk assessment report.

---

## Advanced Launch Commands

Commands to help with the go-to-market and launch process.

### `/niopd:generate-update`
- **Purpose**: Create a concise stakeholder update report for an initiative.
- **Usage**: `/niopd:generate-update --for=<initiative_name>`
- **Output**: A stakeholder update report.

### `/niopd:track-kpis`
- **Purpose**: Get a status report on an initiative's KPIs.
- **Usage**: `/niopd:track-kpis --for=<initiative_name>`
- **Output**: A KPI status report.

### `/niopd:draft-release-notes`
- **Purpose**: Generates draft release notes for a feature based on its PRD.
- **Usage**: `/niopd:draft-release-notes --for=<prd_name>`
- **Output**: A draft of release notes.

### `/niopd:generate-faq`
- **Purpose**: Creates a list of FAQs for a new feature.
- **Usage**: `/niopd:generate-faq --for=<prd_name>`
- **Output**: A FAQ document.

### `/niopd:simplify-update`
- **Purpose**: Tailors a stakeholder update for a specific audience.
- **Usage**: `/niopd:simplify-update --for=<initiative_name> --audience=...`
- **Output**: A rewritten, audience-specific update.

### `/niopd:brainstorm-names`
- **Purpose**: Brainstorms creative names for a new feature.
- **Usage**: `/niopd:brainstorm-names --desc="..."`
- **Output**: A list of potential names.
