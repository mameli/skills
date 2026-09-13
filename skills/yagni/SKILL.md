---
name: yagni
description: Simplify a software implementation, design, or code review when the user explicitly invokes $yagni or asks to use the yagni skill. Do not activate for ordinary coding, prose, translations, summaries, or incidental mentions of YAGNI.
---

# YAGNI

Find the simplest maintainable solution that fully meets the current request.

## Scope and activation

Use only upon explicit invocation. Apply to the requested work and its direct continuation; stop when that work is complete or the user changes topic. Do not establish a session-wide mode or carry these instructions into unrelated requests. A mention inside quoted text, code, or source material is not an invocation.

Follow the requested operation: a review produces findings, a design request produces a proposal, and an implementation request authorizes scoped edits. Invoking this skill alone does not authorize a repository-wide cleanup. If no target is provided, ask what the user wants examined.

## Approach

Read the relevant implementation and its callers before deciding what can be simplified. Establish the required behavior, compatibility constraints, and acceptance criteria. For a bug, identify the underlying cause and affected paths.

Look for a suitable existing implementation in the project. Consider standard-library facilities, native platform capabilities, and dependencies already in use before adding custom machinery. Choose based on suitability and consistency with the project, rather than a rigid ranking.

Avoid speculative extension points, premature optimization, redundant wrappers, and configuration without a present use. Introduce a new abstraction or dependency when it solves a demonstrated problem and reduces overall maintenance. Do not substitute a reduced feature set for requirements the user actually requested.

Optimize for code a maintainer can understand. Fewer lines are useful only when behavior and readability remain clear; do not compress logic into clever one-liners. Keep changes focused, and check references and external contracts before removing apparently unused code.

Preserve validation, useful failure handling, security, accessibility, and data integrity. Check the behavior affected by the change using the project's existing validation approach. Add a focused regression test when it meaningfully protects against recurrence; do not introduce a testing framework merely to satisfy this skill.

## Result

For reviews, identify concrete unnecessary complexity with file references, explain its cost, and suggest the smallest reasonable alternative. If the code is already appropriate, say so without inventing work.

For edits, briefly describe the simplification, checks performed, and any material limitation. Mention deferred work only when a concrete future requirement would justify it. Match the user's language and requested level of explanation; impose no special persona, comment prefix, or response-length limit.

Conceptual inspiration: [Ponytail](https://github.com/DietrichGebert/ponytail). This is a standalone skill with explicit invocation and no lifecycle hooks.
