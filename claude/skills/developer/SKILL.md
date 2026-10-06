---
name: developer
description: Instructs on how approach software development lifecycle
allowed-tools: Bash(coderabbit:*)
---

# Development Workflow

Good practices on code development life cycle that will help creating good and production-ready code. These practices integrates your development with CI/CD environments and powerful feedback tools

## Good practices

Use the following good practices and steps when you reach a goal state of implementation of a given task.

### Request code review (CodeRabbit tool)

Using this tool gives you the abilities to find bugs, security issues, and quality risks in changed code; Groups findings by severity (Critical, Warning, Info). It works on staged, committed, or all changes; supports base branch/commit.

Refer to `references/code-rabbit.md`

### Opening a Pull Request

If requested by the user, and when convenient, you may want to create a new branch or use a existing one if its not master or main. And also create a Pull Request. For doing this use the Github CLI!

Refer to `references/github-cli.md`

### Checking PR Code Integration state

After a PR is open it auto triggers a CI pipeline. To validate issues on pipelines, use the circleci-mcp-server
