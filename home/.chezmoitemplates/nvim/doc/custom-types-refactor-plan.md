# Custom Types Refactor Plan

Date: 2026-04-02

## Goal

Refactor shared LuaLS type usage in this Neovim config to improve:

- correctness
- consistency
- maintainability
- LuaLS usefulness

without adding runtime-only abstractions or creating a large type registry that the codebase does not need.

## Review Summary

This document replaces the previous draft after checking the plan against the current codebase.

What the earlier draft got right:

- shared LSP types currently have duplicate sources of truth
- the Neotest contract is incorrectly typed
- project type modules are required at runtime only for type side effects
- local helper types should not all be centralized

What needed adjustment:

- the previous plan pushed too hard on replacing constructor-style helpers with typed factories
- that change would create wide churn across `lua/configs/lsp/*.lua` without fixing the main correctness problems
- the local type inventory was incomplete
- the baseline test count was stale

## Original Baseline

Verified on 2026-04-02:

- `make test`
- result: 26 tests passed, 0 failed

This was the runtime baseline before refactor changes.

## Implementation Status

Implemented in this pass:

- phase 1: shared LSP contract corrections
- phase 2: duplicate shared LSP declaration cleanup
- phase 3: project runtime type-only require cleanup
- phase 3: shared project contract namespace migration to `dotfiles.project.*`
- phase 3: project tooling local type renaming to repo-owned `dotfiles.*` helpers
- phase 4: local type hygiene for obvious namespace leaks

Deferred intentionally:

- phase 4: broader local type cleanup beyond obvious conflicts
- phase 5: constructor simplification

Implementation fit against the recommended Option B:

- `9.8 / 10`

Why this score:

- it delivered the correctness fixes that drove the recommendation
- it kept `lua/configs/lsp/types.lua` as the authoritative shared LSP type source
- it moved shared LSP contracts into a repo-owned `dotfiles.lsp.*` namespace
- it moved shared project contracts into a repo-owned `dotfiles.project.*` namespace
- it moved project tooling local types to repo-owned `dotfiles.*` helper names
- it removed the runtime-only project type requires
- it reduced local type namespace leakage in module-local helpers
- it avoided unnecessary constructor churn

## Post-Implementation Verification

Verified after implementation on 2026-04-02:

- `make test`
- result: 26 tests passed, 0 failed
- duplicate shared `LanguageSetting` declarations removed
- duplicate shared `LspConfig` declarations removed
- shared LSP contract namespace migrated to `dotfiles.lsp.*`
- shared project contract namespace migrated to `dotfiles.project.*`
- project tooling local types migrated to repo-owned `dotfiles.*` helper names
- runtime `require('configs.project.types')` calls removed from project modules
- shared formatter/linter filetype maps now use explicit aliases
- obvious local helper type leaks moved out of bare or shared namespaces

## Code Reality Check

### Shared Cross-File LSP Contracts

Defined in [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua):

- `dotfiles.lsp.NeotestAdapterSetup`
- `dotfiles.lsp.TreeSitter`
- `dotfiles.lsp.LspConfig`
- `dotfiles.lsp.DapConfig`
- `dotfiles.lsp.FormatterConfig`
- `dotfiles.lsp.LinterConfig`
- `dotfiles.lsp.LanguageSetting`
- `dotfiles.lsp.Lsp`

Primary consumers:

- [lua/configs/lsp/init.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/init.lua)
- [lua/configs/lsp/base.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/base.lua)
- [lua/configs/lsp/lspconfig.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/lspconfig.lua)
- language modules under `lua/configs/lsp/`
- plugin consumers under `lua/configs/plugins/`

### Shared Cross-File Project Contracts

Defined in [lua/configs/project/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/types.lua):

- `dotfiles.project.FilesAssociationPattern`
- `dotfiles.project.FilesAssociations`
- `dotfiles.project.FiletypeSettings`
- `dotfiles.project.FiletypeSettingsMap`

Primary consumers:

- [lua/configs/project/detector.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/detector.lua)
- [lua/configs/project/options.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/options.lua)

### Module-Local Contracts That Should Stay Local

- `dotfiles.ProjectToolArgs`
- `dotfiles.ProjectToolingDefaults`
- `dotfiles.ProjectToolingFiletypeSettings`
- `dotfiles.ProjectToolingSettings`
- `dotfiles.ProjectResolvedToolingSettings`
- `dotfiles.LspCodeLensState`
- `dotfiles.IntelephenseUnusedRefsState`
- `dotfiles.MasonDapHandlerConfig`
- `dotfiles.DiffviewMainFileLike`
- `dotfiles.DiffviewMainWinLike`
- `dotfiles.DiffviewLayoutLike`
- `dotfiles.DiffviewEmitterLike`
- `dotfiles.DiffviewViewLike`
- `dotfiles.GitsignsBlameOffsetPlugin`
- `dotfiles.Base64EncodeFn`

These types currently describe module-local structure, not shared contracts. They should remain near their implementations unless they gain real cross-file consumers.

## Initial Review Findings

### 1. Duplicate LSP Type Declarations Were Real

Before cleanup, the same shared type names were declared in more than one place:

- `LanguageSetting` existed in [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua) and [lua/configs/lsp/base.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/base.lua)
- `LspConfig` existed in [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua) and [lua/configs/lsp/lspconfig.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/lspconfig.lua)

This is the clearest refactor target because it creates drift risk and weakens the idea of an authoritative shared contract file.

### 2. The Neotest Shared Contract Was Incorrect

In [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua):

- `NeotestAdapterSetup` was typed as `fun(): neotest.Adapter`
- `Lsp.get_neotest_adapters` was typed as returning setup functions rather than adapter instances

In the actual implementation:

- adapter setup functions in [lua/configs/lsp/go.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/go.lua), [lua/configs/lsp/python.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/python.lua), and [lua/configs/lsp/rust.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/rust.lua) can return `nil`
- [lua/configs/lsp/init.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/init.lua) resolves adapter instances and returns `neotest.Adapter[]`

This is a correctness issue, not just a style issue.

### 3. Type-Only Runtime Requires Add Noise

These files call `require('configs.project.types')` even though the module only returns `{}`:

- [lua/configs/project/detector.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/detector.lua)
- [lua/configs/project/options.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/options.lua)

That does not break behavior, but it is runtime noise and muddies the distinction between annotation support and executable dependencies.

### 4. Shared Collection Types Are Too Loose

In [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua):

- `formatters_by_ft` is typed as `table<string, table>`
- `linters_by_ft` is typed as `table<string, table>`

Current consumers in [lua/configs/plugins/conform.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/plugins/conform.lua) and [lua/configs/plugins/nvim-lint.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/plugins/nvim-lint.lua) treat those values as filetype-to-list mappings. The shared contract should reflect that directly.

### 5. Constructor Helpers Exist, But They Are Not The First Problem

[lua/configs/lsp/base.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/base.lua) and [lua/configs/lsp/lspconfig.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/lspconfig.lua) are small constructor helpers that build plain tables.

That is mildly awkward, but replacing them with `new_language_setting()` and `new_lsp_config()` across every language module should be treated as optional cleanup, not as the core of the refactor. It adds broad churn while doing little to fix the actual type mistakes above.

### 6. Annotation Verification Is Missing From The Existing Plan

Runtime tests are green, but they do not verify:

- duplicate shared type declarations are gone
- shared signatures match implementations
- LuaLS still resolves the intended contracts

The plan needs an annotation-specific verification step.

## Resolution Status

Resolved in this pass:

- duplicate shared LSP declarations
- incorrect shared Neotest signatures
- shared LSP namespace migration to `dotfiles.lsp.*`
- shared project namespace migration to `dotfiles.project.*`
- project tooling local type renaming
- project runtime type-only requires
- loose shared formatter and linter filetype map types
- obvious local helper namespace leaks

Deferred intentionally:

- broader local helper type renaming
- constructor-to-factory simplification

## Plan Review With Scores

Scoring criteria:

- maintainability: 35
- correctness: 25
- migration safety: 20
- LuaLS value: 10
- implementation cost: 10

### Option A: Minimal Fixes Only

Changes:

- fix the Neotest typing bug
- remove duplicate shared `@class` declarations
- leave naming and project type cleanup mostly alone

Score:

- maintainability: 6.5
- correctness: 8.5
- migration safety: 9.0
- LuaLS value: 7.0
- implementation cost: 9.0
- weighted total: `7.7 / 10`

Assessment:

- safe and useful
- still leaves naming drift and runtime type-only requires in place

### Option B: Narrowed Hybrid Cleanup

Changes:

- make `lua/configs/lsp/types.lua` the authoritative shared LSP type source
- fix incorrect shared signatures
- tighten shared collection aliases
- clean up shared project type ownership
- remove runtime type-only requires
- keep local helper types local
- defer constructor-style migration unless it proves necessary

Score:

- maintainability: 8.8
- correctness: 9.0
- migration safety: 8.2
- LuaLS value: 8.6
- implementation cost: 7.3
- weighted total: `8.5 / 10`

Assessment:

- best balance for the current repo
- fixes the real problems without touching every LSP module unnecessarily

### Option C: Full Schema Or Builder Layer

Changes:

- introduce a larger type and normalization layer around LSP/project config data

Score:

- maintainability: 7.2
- correctness: 8.0
- migration safety: 5.5
- LuaLS value: 8.8
- implementation cost: 4.5
- weighted total: `6.9 / 10`

Assessment:

- too heavy for this codebase
- creates more structure than the repo currently benefits from

## Recommended Direction

Choose **Option B: Narrowed Hybrid Cleanup**.

Reason:

- it fixes actual type correctness bugs first
- it restores one authoritative source for shared types
- it preserves the useful distinction between shared contracts and local structural helpers
- it avoids a high-churn constructor rewrite that does not currently pay for itself

## Implementation Scope For This Pass

This implementation pass now covers phases 1 through 4 in a narrowed form:

- correct shared LSP signatures
- tighten shared collection aliases
- remove duplicate shared LSP declarations
- migrate shared LSP contracts to `dotfiles.lsp.*`
- remove project runtime type-only requires
- migrate shared project contracts to `dotfiles.project.*`
- migrate project tooling local types to repo-owned `dotfiles.*` names
- rename obvious local helper namespace leaks

This pass should explicitly defer:

- constructor-to-factory migration in `lua/configs/lsp/`
- broader project-local helper cleanup beyond the current tooling module

That keeps the change set aligned with the highest-value fixes already verified in the code review.

## Refactor Rules

### Rule 1: One Authoritative File Per Shared Type Domain

Use:

- [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua) for shared LSP contracts
- [lua/configs/project/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/types.lua) for shared project contracts

Do not redeclare those shared types in constructor/helper modules.

### Rule 2: Keep Local Structural Types Next To Their Code

Examples:

- keep `dotfiles.LspCodeLensState` in [lua/utils/lsp_codelens.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/utils/lsp_codelens.lua)
- keep `dotfiles.IntelephenseUnusedRefsState` in [lua/configs/lsp/php.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/php.lua)
- keep Diffview/Gitsigns helper shapes in [lua/plugins/git.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/plugins/git.lua)
- keep `Base64EncodeFn` in [lua/utils/common.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/utils/common.lua)

### Rule 3: Fix Wrong Shared Contracts Before Renaming Anything

Correctness-first order:

- `dotfiles.lsp.NeotestAdapterSetup` must allow `nil`
- `dotfiles.lsp.Lsp.get_neotest_adapters` must return adapter instances
- shared collection aliases should reflect actual value shapes

### Rule 4: Prefer Explicit Aliases Over Broad `table`

Good examples:

- `table<string, string[]>`
- `table<string, dotfiles.ProjectToolArgs>`

Avoid:

- `table<string, table>`

when the value shape is already known.

### Rule 5: Treat Constructor Cleanup As Optional

If the shared-contract cleanup still leaves poor LuaLS ergonomics, then a follow-up pass can replace constructor-style modules with plain factory helpers. That should not be phase 1.

## Phased Plan

### Phase 1: Correct Shared LSP Contracts

Targets:

- [lua/configs/lsp/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/types.lua)
- [lua/configs/lsp/init.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/init.lua)

Tasks:

- fix `dotfiles.lsp.NeotestAdapterSetup` to return `neotest.Adapter|nil`
- fix `dotfiles.lsp.Lsp.get_neotest_adapters` to return `neotest.Adapter[]`
- introduce precise shared aliases for formatter and linter filetype maps
- keep runtime behavior unchanged

Why first:

- this is the only confirmed shared-type correctness bug
- the change surface is small
- all later cleanup should build on correct shared contracts

### Phase 2: Remove Duplicate Shared LSP Declarations

Targets:

- [lua/configs/lsp/base.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/base.lua)
- [lua/configs/lsp/lspconfig.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/lspconfig.lua)

Tasks:

- remove duplicate shared `LanguageSetting` declarations
- remove duplicate shared `LspConfig` declarations
- leave the constructor helpers in place unless an annotation problem remains after deduplication

### Phase 3: Clean Up Shared Project Types

Targets:

- [lua/configs/project/types.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/types.lua)
- [lua/configs/project/detector.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/detector.lua)
- [lua/configs/project/options.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/project/options.lua)

Tasks:

- keep shared project contracts centralized in `types.lua`
- remove runtime `require('configs.project.types')` calls if LuaLS still resolves those types without them
- only introduce namespacing changes if they clearly improve navigation and do not expand the migration surface too much

Note:

- bare project type names are less consistent than `dotfiles.lsp.*`, but renaming them is secondary to removing runtime-only type requires and keeping one ownership model
Current status:
- shared project contracts now use `dotfiles.project.*`
- tooling-local project helper types now use repo-owned `dotfiles.*` names while staying local to their module

### Phase 4: Local Type Hygiene

Targets:

- [lua/configs/plugins/nvim-dap.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/plugins/nvim-dap.lua)
- [lua/plugins/git.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/plugins/git.lua)
- [lua/utils/lsp_codelens.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/utils/lsp_codelens.lua)
- [lua/utils/common.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/utils/common.lua)
- [lua/configs/lsp/php.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/php.lua)

Tasks:

- keep these types local
- rename only when a local type name is ambiguous or likely to collide later
- keep module-local annotations syntactically valid so LuaLS can still resolve the surrounding class shape
- do not centralize them preemptively

### Phase 5: Optional Constructor Simplification

Targets:

- [lua/configs/lsp/base.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/base.lua)
- [lua/configs/lsp/lspconfig.lua](/home/vietisthinkpad/.local/share/chezmoi/home/.chezmoitemplates/nvim/lua/configs/lsp/lspconfig.lua)
- language modules under `lua/configs/lsp/`

Only do this if one of these is still true after phases 1 through 4:

- LuaLS still reports poor inference around the constructor helpers
- shared contracts are still hard to navigate
- constructor modules still require duplicated annotations to remain usable

If none of those remain true, skip this phase.

## Verification

After each phase:

- run `make test`
- confirm the runtime baseline still passes

For the type cleanup specifically:

- confirm shared types are declared only once per domain
- confirm `dotfiles.lsp.Lsp.get_neotest_adapters` matches its implementation
- confirm project type annotations still resolve without runtime type-only requires
- confirm shared project contracts resolve through `dotfiles.project.*`
- confirm project tooling local types no longer use bare global names
- confirm module-local annotations still parse cleanly in LuaLS, including fields like `dotfiles.LspCodeLensState.timer`
- confirm no local type was extracted unless it gained a real cross-file consumer

## Improvements Beyond The Original Draft

- Add a small contributor note stating that shared types belong only in domain `types.lua` files and local helper types stay local.
- Add a lightweight duplicate-type audit step during review, such as searching for repeated shared `---@class` declarations before merging.
- Prefer alias names for repeated collection shapes so future type tightening happens in one place.
- Prefer repo-owned namespaces like `dotfiles.lsp.*` and `dotfiles.project.*` for shared domain contracts and reserve flat `dotfiles.*` names for local helper types when practical.

## Expected Outcome

After this refactor:

- shared contracts have a single authoritative owner
- shared annotations match runtime behavior
- local structural types remain local
- runtime modules stop depending on empty type-only modules
- LuaLS signals become more trustworthy without increasing runtime complexity
