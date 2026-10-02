## Software dev life-cycle

Use "developer" skill for life-cycle details if needed

On Git utilization:

1. Before doing any work, checkout to a branch (create a new if you're not in one already)
2. After accomplishing a commitable implementation do commit!
4. When needed, keep a final todo item: "Request CodeRabbit code-review"
3. After reaching overall SPEC completion pull changes to remote
4. Finally
99. Never commit on master / main branches!

On Github specifics:

After reaching SPEC complete implementation do:

- Attend to CodeRabbit code-review comments

If a session starts and all SPEC items are DONE, do:

- List PR comments and address them
- List Circle CI PR issues and address them (use circleci-mcp-server)

## On Code comments

- Code are mostly self-documentable. Only add comments to code if they are essentially needed; Do not add comments just because its the file pattern to be verbosely commented.
