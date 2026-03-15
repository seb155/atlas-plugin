---
name: subagent-dispatch
description: "Dispatch Sonnet subagents per task. 2-stage review: spec compliance then code quality. Sequential dispatch, not parallel."
---

# Subagent Dispatch

## Overview

Execute plan tasks by dispatching specialized subagents. Each task gets its own Sonnet subagent for implementation, followed by 2-stage review.

## Model Strategy

- **Implementation subagents**: Sonnet 4.6 (efficient, high quality)
- **Review subagents**: Sonnet 4.6 (spec + quality review)
- **Never**: Haiku for implementation (too shallow)
- **Never**: Opus for implementation (too expensive for routine coding)

## Per-Task Workflow

### 1. Dispatch Implementer
```
Agent tool:
  subagent_type: general-purpose
  model: sonnet
  prompt: "{full task text from plan + context + constraints}"
```

Provide the subagent with:
- Full task text (don't make it read the plan file)
- Relevant file paths and current content
- Test commands to run
- Commit message format

### 2. Handle Subagent Questions
If subagent returns NEEDS_CONTEXT:
- Provide the missing context
- Re-dispatch with additional info

### 3. Spec Compliance Review
Dispatch a review subagent:
```
Agent tool:
  subagent_type: feature-dev:code-reviewer
  model: sonnet
  prompt: "Review this implementation against the spec: {spec text}"
```

Check: Does the code match what the plan specified?
- If issues → implementer fixes → re-review
- Loop until spec compliance ✅

### 4. Code Quality Review
Dispatch quality review:
```
Agent tool:
  subagent_type: feature-dev:code-reviewer
  model: sonnet
  prompt: "Review code quality: {file paths changed}"
```

Check: Is the code well-built?
- If issues → implementer fixes → re-review
- Loop until quality ✅

### 5. Mark Complete
- TaskUpdate(status: "completed")
- Move to next task

## Rules

- **Sequential**: 1 task at a time (not parallel — tasks may depend on each other)
- **Never skip reviews**: Both spec compliance AND code quality are mandatory
- **Max 2 review loops**: If still failing after 2 fix rounds → escalate to user
- **Full context in prompt**: Don't make subagents read plan files — provide full text
