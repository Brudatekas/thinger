---
description: Workflow for building and accessing the DocC documentation catalog
---

# Build Documentation Workflow

// turbo-all

## 1. Build the Documentation Catalog
This step generates the Swift-DocC documentation for the project.

```bash
make build-docs
```

## 2. Review the Output
Once the build completes successfully, Xcode puts the `.doccarchive` file inside the derived data path. You can open and view it in the Xcode Developer Documentation window:

```bash
open build/docs/Build/Products/Debug/thinger.doccarchive
```

## When to Use This Workflow
- After adding or modifying `///` DocC comments in source files.
- When you want to preview the overall structure of `thinger.docc`.
- To ensure documentation syntax isn't broken before committing.
