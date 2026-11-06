## Git workflow

Before changing files:
- Check the current branch, working tree, and remote.
- Fetch the latest changes from origin.
- If on main or master, create a descriptive feature branch from
  the latest origin/main or origin/master before editing.
- Preserve existing uncommitted work and local commits. If they prevent
  safely branching from the latest remote code, explain the conflict.
- If already on a feature branch, continue using it.

After each completed logical change:
- Run the project's required checks and fix failures.
- Review the diff and stage only files belonging to the change.
- Exclude generated Godot caches, logs, and secrets.
- Commit with a descriptive message.
- Push the feature branch to origin, setting its upstream when needed.
- Verify the push succeeded and report the branch and commit.

These instructions authorize routine commits and feature-branch pushes
without asking again. Never force-push or merge into main/master unless
explicitly requested. Report any blocked commit or push.