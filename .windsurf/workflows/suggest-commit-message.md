---
description: Suggests a git commit message based on staged changes, supporting target directories (e.g., submodules) and using XML-style tags for context.
---

<user_inputs>
- Output the target directory(e.g., path to a submodule) **provided by the user** into <target_directory> xml tag.
</user_inputs>

<check_target_directory>
- Check if a <target_directory> was specified when this workflow was invoked.
- If a <target_directory> is provided, all subsequent `git` commands in this workflow (executed via the `run_command` tool) **MUST** use this <target_directory> as their Current Working Directory (`Cwd`).
- If no <target_directory> is specified or <target_directory> is empty, `git` commands should be run from the current project root or the directory where the workflow was initiated.
- Output the working directory context into <working_directory> xml tag.
</check_target_directory>

<search_git_commands>
- **Plan Git Documentation Queries:**
    - List of queries:
        1. `no pager` (Purpose: to identify general options for making git commands non-interactive, suitable for automation)
        2. `viewing staged changes` (Purpose: to find the command to show the differences between the files in the staging area)
    - **ALWAYS USE `code-reasoning` tool** to break down plan process in step by step.
    - Output the list of planned queries into <planned_git_doc_queries> xml tag.
- **Execute Git Documentation Queries using `context7`:**
    - First, call `mcp1_resolve-library-id` with `libraryName: "git"` to get the Context7 ID for `Git Documentation` (e.g., `/git/htmldocs`), **NOT** `git source code`. Store this ID.
    - Then, for **each query** identified in <planned_git_doc_queries>:
        - Call `mcp1_get-library-docs` using the stored Git Documentation ID and the specific query string (with `tokens: 2000`).
    - Ensure all queries are executed and their results collected.
<important>
- **Prioritize Non-Interactive Commands:** When analyzing results from `mcp1_get-library-docs`, prioritize commands marked as non-interactive or including **"no pager"**.
</important>
- Collate and output the relevant command information into <git_commands> xml tag.
</search_git_commands>

<get_staged_files_changes>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<git_commands>`, `<working_directory>`.
- Using the non-interactive git commands from <git_commands> and the directory context from <working_directory>:
    - Run the identified non-interactive git command to see the specific modifications in staged files (e.g., `git --no-pager diff --staged`). This command also MUST use the `Cwd` from <working_directory> if applicable and MUST NOT require user interaction.
- Output the diff of content changes into <staged_changes_diff> xml tag.
</get_staged_files_changes>

<analyze_changes>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<staged_changes_diff>`.
- Analyze <staged_changes_diff> focus on:
    - The primary purpose of the changes (e.g., adding a feature, fixing a bug, updating documentation, refactoring code).
    - Key technical details of the modifications.
- **ALWAYS USE `code-reasoning` tool** to break down analysis into step by step.
- Output result into <analyzed_result> xml tag.
</analyze_changes>

<fetch_conventional_commits_spec>
- **Fetch Conventional Commits Specification using `context7`:**
    - First, call `mcp1_resolve-library-id` with `libraryName: "conventionalcommits"` to get list of available libraries related to `conventionalcommits`. Then select the library has description similar to `The conventional commits specification`. Store the ID into <conventional_commits_spec_id> xml tag.
    - Then, call `mcp1_get-library-docs` with the retrieved <conventional_commits_spec_id>, setting `tokens: 8000` (or a similarly large value) to ensure the full specification context is fetched. Store the output into <conventional_commits_spec> xml tag.
</fetch_conventional_commits_spec>

<formulate_commit_message>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<analyzed_result>`, `<conventional_commits_spec>`.
- Formulate Commit Message follow below instructions:
    - Provide the <analyzed_result> (from the <analyze_changes> step) and the fetched <conventional_commits_spec> as inputs.
    - Instruct the tool to use the technical details and purpose of the changes from <analyzed_result> to create the content of a commit message. This message must then be formulated to strictly adhere to all rules, types, scopes, and structures (including header, body, and footer) as defined in the <conventional_commits_spec>.
- **ALWAYS USE `code-reasoning` tool** to break down formulation into step by step.
- Output the formulated commit message into <formulated_commit_message> xml tag.
</formulate_commit_message>

<output>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<formulated_commit_message>`.
- Present the final <formulated_commit_message> (which includes the title and body) as a single block of Markdown text, enclosed within ` ```md ... ``` ` for easy copying.
<example>
```md
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```
</example>
</output>