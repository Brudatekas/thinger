---
description: Add all files, commit with a descriptive message, and push to GitHub
---

// turbo-all

## Steps

1. Stage all changes:
```bash
cd /Users/tarikkhafaga/macosprojs/thinger && git add -A && git status
```

2. Inspect the actual diff of the staged changes to understand what was modified:
```bash
cd /Users/tarikkhafaga/macosprojs/thinger && git diff --staged --stat && echo "---FULL DIFF---" && git diff --staged
```

3. Based on the diff output from the previous step, write a good conventional commit message. The commit message should:
   - Be derived from the **actual code changes** shown in the diff, not assumptions
   - Use a conventional commit prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, etc.)
   - Have a concise subject line (≤72 chars)
   - Include a body with bullet points summarizing the key changes
   - Example format:
```
feat: short summary of what changed

- Detail about change 1
- Detail about change 2
```

4. Commit:
```bash
git commit -m "<your commit message>"
```

5. Push to GitHub:
```bash
git push
```

If the push fails because there's no upstream, run:
```bash
git push --set-upstream thinger master
```
