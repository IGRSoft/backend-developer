---
description: Review server-produced HTML, emails, error messages, and response metadata for accessibility defects
argument-hint: [path to templates, email/document generators, error handlers, or middleware] [--html] [--emails] [--errors] [--metadata]
allowed-tools: Read, Glob, Grep
model: haiku
estimated-cost:
  min-tokens: 2000
  max-tokens: 7000
  model-distribution:
    haiku: 70%
    sonnet: 25%
    opus: 5%
---

# Server-Produced Content Accessibility Review

Review the accessibility of what a back-end service actually emits: server-rendered HTML templates, transactional emails and generated documents, error and validation payloads, and the response metadata a client needs to render accessible output. This is a narrow, honest slice of WCAG — **a back-end plugin cannot audit a UI it does not own**, and this command does not pretend to.

[Extended thinking: Most accessibility work lives in the client, and this command deliberately refuses to claim it. What a service genuinely owns is narrower and still real: the Thymeleaf/Jinja/ERB/Blade/Razor template that ships the actual DOM, the transactional email with an image and no alt text and no plain-text part, the validation response that says "fix the red field" so no screen-reader user can act on it, and the `Content-Language` header a client needs to announce the right language. Those are four checkable, server-side things. The temptation is to inflate this into a full WCAG 2.2 audit with contrast ratios and focus order — that would be dishonest, because the server never sees the rendered page. So the review is one pass, cheap, over four categories, and the Out of Scope section is a first-class part of the output rather than a footnote: it names what was not checked and points at the plugin that owns it. A short honest report beats a padded one.]

## Scope

This command reviews four things a back-end service is genuinely responsible for.

**1. Server-rendered HTML** — templates the service itself emits.

| Check | What to look for |
|-------|------------------|
| Semantic elements | `<button>`/`<a>`/`<nav>`/`<main>`/`<table>` used for their meaning, not `<div>` with a click handler |
| Document language | `lang` attribute present on `<html>`, and correct when the template is localized |
| Heading order | One `<h1>`; no skipped levels; headings not chosen for font size |
| Form labels | Every input has a `<label for>` or an equivalent programmatic association |
| Image alternatives | `alt` on every server-generated `<img>`; empty `alt=""` on decorative images |
| Table structure | `<th>` with `scope`, `<caption>` where the table needs one |

Template engines in range: Thymeleaf, JSP, Django templates, Jinja2, ERB/Haml, Blade, Twig, Razor, EJS, Handlebars/Pug.

**2. Emails and generated documents** — anything the service renders and sends.

| Check | What to look for |
|-------|------------------|
| Plain-text alternative | Multipart email includes a real `text/plain` part, not an empty stub |
| Image alternatives | `alt` on every image in the email/PDF template; no meaning carried by an image alone |
| Reading order | Generated PDF/DOCX content flows in logical order; not layout-table-only or absolutely positioned |
| Contrast in templates | Hardcoded foreground/background pairs in the template meet WCAG AA (4.5:1 body, 3:1 large) |
| Link text | Descriptive link text, not bare "click here" or a raw URL |

**3. Error and validation responses** — what a client is given to display.

| Check | What to look for |
|-------|------------------|
| Human-readable message | A sentence a user can act on, not a bare code, enum, or stack trace |
| Field association | Field-level errors carry a stable field identifier a client can bind to its control |
| No sensory-only phrasing | Not "fix the red field" or "see the box on the right" — name the field |
| No leaked internals | Exception text, SQL, and file paths are not the user-facing message |
| Consistent envelope | One error shape across endpoints, so a client renders errors one way |

**4. WCAG-relevant response metadata** — headers and semantics a client depends on.

| Check | What to look for |
|-------|------------------|
| `Content-Language` | Set, and matching the language of the body actually returned |
| `Content-Type` + charset | Correct type and explicit `charset=utf-8` |
| HTTP status semantics | Status reflects the real outcome; errors are not returned as `200` with an error body |
| `Retry-After` | Present on `429`/`503`, so a client can tell the user how long to wait |
| Timeouts and session expiry | Session/token windows and their warning lead time respect WCAG 2.2 § 2.2.1 "Enough Time" — user-extendable, or at least announced |
| Pagination / `Link` | Navigable pagination metadata (`Link` rel next/prev, or cursor fields) so a client can render real navigation |

## Out of Scope

This command does **not** check the following, and will not claim to. Each belongs to the plugin that owns the rendered UI.

| Not checked here | Owner |
|------------------|-------|
| Client-side rendering, SPA output, hydrated DOM | `frontend-developer` plugin |
| Focus management, focus order, focus visibility | `frontend-developer` plugin |
| Keyboard navigation and shortcuts | `frontend-developer` plugin |
| Screen-reader behavior, live regions, ARIA in the running app | `frontend-developer` / `apple-developer` / `android-developer` |
| Color contrast of the shipped UI (as rendered, with the app's CSS/theme) | `frontend-developer` plugin |
| Motion, animation, and reduced-motion preferences | `frontend-developer` plugin |
| Native app accessibility (VoiceOver, TalkBack, Dynamic Type) | `apple-developer` / `android-developer` |

If a request needs any of the above, say so and point at the owning plugin instead of producing a thin approximation.

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Read-only.** Report findings; never edit a template, handler, or header. Fixes go to `/backend-developer:fix-quick` or the owning stack developer.
2. **Stay inside the four categories.** Do NOT extend this into a full WCAG 2.2 audit. If the scope contains no server-rendered content, no generated documents, and no error/metadata surface, report exactly that and stop.
3. **Every finding is located.** `file:line` plus the WCAG success criterion. A finding you cannot locate is not a finding.
4. **Never assert about the rendered result.** The server does not see the page. Report what the template or handler emits, and say "as emitted" — do not claim a contrast ratio or a focus behavior in the running UI.
5. **Always print the Out of Scope section.** It is part of the output, not an optional note. The reader must know what was not checked.
6. **No manufactured findings.** If a category is clean, one line saying so. Do NOT pad.
7. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Review the server-rendered templates in a service
/backend-developer:analyze-accessibility src/main/resources/templates/

# Review transactional email templates
/backend-developer:analyze-accessibility app/mailers/ --emails

# Review error and validation response shaping
/backend-developer:analyze-accessibility src/errors/ --errors

# Review response headers and metadata middleware
/backend-developer:analyze-accessibility src/middleware/ --metadata

# Full pass over one service (all four categories)
/backend-developer:analyze-accessibility services/checkout/
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working paths | Templates, mailers/document generators, error handlers, or middleware to review. |
| `--html` | auto | Restrict to server-rendered HTML templates. |
| `--emails` | auto | Restrict to email and generated-document templates. |
| `--errors` | auto | Restrict to error and validation response shaping. |
| `--metadata` | auto | Restrict to response headers and HTTP/pagination semantics. |

With no flag, run whichever categories the scope actually contains — detected by file type and layout (template extensions, mailer/document directories, error-handling middleware, header-setting middleware).

## Workflow

Single read-only pass. There is no fan-out — this review is small by design.

**Resolve `{active_categories}` first.** If any of `--html`, `--emails`, `--errors`, `--metadata` is passed, `{active_categories}` is exactly the set named by those flags — the flags restrict, and they override content detection even when the scope contains more. If none is passed, `{active_categories}` is the set content detection found in the scope. Either way, state the resolved set and its source (flags or detection) in the report, and skip the numbered checks below for every category not in the set — a restricted run must not report findings for a category the caller excluded.

**Use Task tool with subagent_type="backend-developer:backend-developer"**
- Prompt: "Read-only accessibility review of server-produced content in: {file_list}. Categories active: {active_categories}. Check ONLY what the server emits: (1) server-rendered HTML templates — semantic elements, `lang` attribute, heading order, `<label for>` association, `alt` on server-generated images, `<th scope>`/`<caption>`; (2) transactional emails and generated PDFs/documents — plain-text multipart alternative, image `alt`, logical reading order, hardcoded contrast pairs in the template against WCAG AA, descriptive link text; (3) error and validation responses — human-readable messages rather than raw codes or stack traces, field-level errors carrying a stable field identifier a client can bind to a control, no sensory-only phrasing such as 'fix the red field', no leaked internals, one consistent error envelope; (4) response metadata — `Content-Language` matching the returned body, correct `Content-Type` with explicit charset, honest HTTP status semantics (no error bodies under 200), `Retry-After` on 429/503, session/timeout windows against WCAG 2.2 § 2.2.1 Enough Time, and pagination/`Link` metadata sufficient for a client to render navigation. Do NOT check client-side rendering, focus management, keyboard navigation, screen-reader behavior, rendered-UI contrast, or native-app accessibility — those are out of scope and belong to the frontend/apple/android plugins. Do NOT edit any file. Do NOT assert anything about the rendered page; report only what the template or handler emits. Return findings as `{file, line, category, wcag_criterion, severity (P0-P3), what_is_emitted, fix}`. For any category with no material issue, say so in one line rather than inventing findings."

Then emit the Output Format report, including the Out of Scope section verbatim.

## Output Format

```markdown
## Server-Produced Content Accessibility Review

**Scope:** {resolved paths}
**Categories reviewed:** {html / emails / errors / metadata}
**Files reviewed:** {N}

### Summary
{One or two sentences. If clean: "No accessibility defects found in the server-produced content reviewed."}

| Priority | Count |
|----------|-------|
| P0 | {n} |
| P1 | {n} |
| P2 | {n} |
| P3 | {n} |

### Findings

| P | File:Line | Category | WCAG | What is emitted | Fix |
|---|-----------|----------|------|-----------------|-----|
| P0 | {file}:{line} | {html/email/error/metadata} | {e.g. 1.1.1 Non-text Content} | {the defect as emitted} | {minimal fix} |

### Not Checked (out of scope for a back-end review)
Client-side rendering, focus management, keyboard navigation, screen-reader behavior,
rendered-UI color contrast, motion preferences, and native-app accessibility were NOT
reviewed. Route those to the `frontend-developer`, `apple-developer`, or
`android-developer` plugin — this review covers only what the service emits.
```

Severity follows `skills/_shared/severity-matrix.md`: P0 = the content is unusable with assistive technology (unlabeled form, image-only email with no text part, error message with no actionable text); P1 = a real barrier with a workaround; P2/P3 = degraded experience.

## Error Handling

### No server-produced content in scope
```
Note: No server-rendered templates, document/email generators, error handlers, or
response-metadata code found in the resolved scope.
Resolved scope: {scope}
This service appears to return data only, with rendering owned by a client.
Suggestion: route the accessibility review to the plugin that owns the UI
(frontend-developer, apple-developer, or android-developer).
```

### Request is really about the UI
If the request is about focus, keyboard, screen readers, or the rendered UI's contrast, do not approximate it. Say plainly that a back-end review cannot cover it, name the owning plugin, and offer the in-scope portion (error-message clarity and response metadata) if it is relevant.

### Templates rendered by an engine not on the list
Review the emitted markup structurally anyway — the checks are markup-level, not engine-level — and note the engine in the report header so the reader can judge depth.

## Related commands

- `/backend-developer:review-code` — full correctness and quality review of the same handlers and templates.
- `/backend-developer:gen-api` — establish a consistent error envelope and pagination convention when the findings are structural.
- `/backend-developer:fix-quick` — apply the localized template fixes (`alt`, `lang`, `<label for>`, `<th scope>`).
- `/backend-developer:gen-docs` — document the error-message contract so clients can render it accessibly.
- `/backend-developer:analyze-tech-debt` — escalate a systemic error-envelope or template-sprawl problem into the debt ledger.
