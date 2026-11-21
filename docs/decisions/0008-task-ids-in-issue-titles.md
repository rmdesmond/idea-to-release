# 0008: Put task IDs in issue titles

Date: 2026-11-20
Status: accepted

## Context

Conventions §9 said issue titles carry no ID prefix; the task ID lived only in the body's `Plan-Task:` footer. With 27 plan issues on this repository, finding the issue for a task, or the task for an issue, meant opening issues one at a time. The maintainer asked for task IDs in titles.

## Decision

Issue titles for plan tasks are `T-NNN: <task title>`. plan-to-issues writes the prefix on new issues, and adds it to existing issues that lack it, keeping the rest of the title. Issues for work outside the plan keep plain titles.

The `Plan-Task:` footer stays. It remains the reliable link that plan-to-issues matches on, because anyone can edit a title.

## Consequences

- The issue list reads like the plan, and plan task IDs can be searched for in the tracker.
- Change request titles are unchanged. They follow Conventional Commits and become the commit messages, so the ID stays out of the history; the `Refs: #N` footer links them.
- A title that starts with a different task ID than its footer is treated as a conflict, so a mistyped prefix doesn't go unnoticed.
