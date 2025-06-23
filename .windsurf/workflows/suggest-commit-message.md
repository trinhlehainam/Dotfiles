---
description: Suggests a git commit message based on staged changes, supporting target directories (e.g., submodules) and using XML-style tags for context.
---

<user_inputs>
- **Working Directory (Optional):**
  - Identify by checking the initial command for a path provided either with a keyword (e.g., `dir:`, `target:`, `in: <path>`) or as a standalone argument. Keywords take precedence.
  - If a path is identified, set the <working_directory> XML tag to this path. This directory will be the Cwd for `git` commands.
  - If no path is provided, set the <working_directory> XML tag to the project root/initiation directory.
</user_inputs>

<search_git_commands>
- **Plan Git Documentation Queries:**
    - List of queries:
        1. `no pager` (Purpose: to identify general options for making git commands non-interactive, suitable for automation)
        2. `viewing staged changes` (Purpose: to find the command to show the differences between the files in the staging area)
    - **ALWAYS USE `code-reasoning` tool** to break down plan process in step by step.
    - Output the list of planned queries into <planned_git_doc_queries> xml tag.
- **Execute Git Documentation Queries using `context7` tool:**
    - Use the `context7` tool to search for libraries related to 'Git'. From the list of returned libraries, select the one with the ID `/git/htmldocs` and a description similar to 'HTML Git documentation'. Store this library ID into <git_doc_library_id> xml tag.
    - Then, for **each query** identified in <planned_git_doc_queries>:
        - Use the `context7` tool with <git_doc_library_id> as library ID to retrieve relevant documentation for the query, requesting approximately 2000 tokens.
    - Ensure all queries are executed and their results collected.
<important>
- **Prioritize Non-Interactive Commands:** When analyzing results from `context7` tool, prioritize commands marked as non-interactive or including **"no pager"**.
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
- Use the `context7` tool to find the library ID for 'conventionalcommits'. Select the library whose description is similar to 'The conventional commits specification'. Store the ID into <conventional_commits_spec_id> xml tag.
- Then, use the `context7` tool with the retrieved <conventional_commits_spec_id> to fetch the Conventional Commits specification, requesting approximately 8000 tokens to ensure the full context is retrieved. Store the output into <conventional_commits_spec> xml tag.
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