---
description: "Use when creating or editing Markdown documentation in this repo. Covers bilingual English/Chinese document pairing, mutual links, and keeping translated tutorial docs aligned."
applyTo: "**/*.md"
---
# Markdown Documentation Guidelines

- Keep this repo bilingual for maintained documentation.
- For an English Markdown document like `foo.md`, the Chinese companion should be `foo.zh-CN.md` in the same directory.
- Each English document should link to its Chinese companion near the top.
- Each Chinese document should link back to the English document near the top.
- When editing an English document, update the Chinese companion in the same change when practical.
- When editing a Chinese document, check whether the English source changed and keep the two versions aligned in structure and meaning.
- If only one language version exists, treat the missing companion as documentation debt and prefer adding it when touching that doc.
- Prefer linking to `README.md`, `BUILD_MATRIX.md`, and target-specific walkthroughs instead of duplicating large setup sections.
- Keep command blocks runnable and keep sample outputs short.
- Do not commit generated files under `examples/outputs/`.