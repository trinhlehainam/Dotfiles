---
description: Suggests a Pull Request (PR) message based on changes between the current branch and the default branch, supporting target directories and incorporating best practices.
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
        2. `show current branch name` (Purpose: to find the command to get the name of the currently checked-out branch)
        3. `show remote HEAD branch` (Purpose: to find a reliable command to determine the repository's default branch name, e.g., `origin/HEAD`)
        4. `log commit messages between branches` (Purpose: to get commit messages between the default and current branch)
        5. `show diff content between branches` (Purpose: to get diff content between the default and current branch)
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
- Collate and output the relevant command information into <git_commands_for_pr> xml tag.
</search_git_commands>

<get_diff_info>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<git_commands_for_pr>`, `<working_directory>`.
- Using commands from <git_commands_for_pr> (ensuring they are non-interactive) and directory context from <working_directory>:
    - Execute command to get current branch name. Store as <current_branch>.
    - Execute command(s) to determine the default branch name (e.g., `main`, `master`). Store as <default_branch>.
    - Execute command to get commit messages between <default_branch> and <current_branch>. Store as <commit_messages_diff>.
    - Execute command to get diff content between <default_branch> and <current_branch>. Store as <content_changes_diff>.
</get_diff_info>

<analyze_changes>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<commit_messages_diff>`, `<content_changes_diff>`.
- Analyze the following:
    - Identify themes, types of changes, and overall scope, then present into <commit_messages_diff> xml tag. 
    - Understand the technical impact of code modifications, then present into <content_changes_diff> xml tag.
- Synthesize the analysis into a plan for the PR message, focusing on the following steps:
    - Primary purpose of the PR.
    - Summary of key technical changes.
    - Notable technical decisions or implications.
- **ALWAYS USE `code-reasoning` tool** to break down analysis in step by step. 
- Output result into <analyzed_result> xml tag.
</analyze_changes>

<best_practices>
- **Title:** Ensure it's a clear, specific summary of the PR's goal.
- **Body - Explain Purpose & Changes:**
    - Clearly state the problem solved or feature introduced.
    - Briefly explain the 'what' (key technical changes) and 'why' (reasons/approach).
    - Keep the language technical, concise, and focused.
- **Essential for Reviewers:**
    - If applicable, briefly note how to test the changes.
    - Link to critical issues/tasks if they provide essential context (e.g., `Closes #123`).
- **Review Generated Message:** Check if the AI-suggested message covers these points. Add or refine as needed.
</best_practices>

<formulate_pr_message>
- **Dependency:** This step MUST WAIT for the successful completion of the step(s) producing: `<analyzed_result>`. 
- Based on <best_practices> formulate <analyzed_result> into a PR message:
    - **Title:** A concise summary of the PR's goal.
    - **Body:**
        - Clear statement of purpose.
        - Summary of key technical changes (can be bullet points).
        - Focus on 'what' changed and 'why' technically.
- **ALWAYS USE `code-reasoning` tool** to break down formulation process in step by step.
- Output result into <formulated_pr_message> xml tag.
</formulate_pr_message>

<output>
- Present the final <formulated_pr_message> (which includes the title and body) as a single block of Markdown text, enclosed within ` ```md ... ``` ` for easy copying.
<example>
```md
feat: Implement user profile page with avatar upload

This PR introduces the new user profile page, allowing users to view and update their information, including uploading a profile avatar.

Key technical changes:
- Added `UserProfileController` to handle profile data.
- Implemented `AvatarUploadService` for image processing and storage.
- Updated routing to include `/profile` endpoint.
- New database schema for user profiles.
```
</example>
</output>
