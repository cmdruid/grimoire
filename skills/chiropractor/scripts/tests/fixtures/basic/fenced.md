# fenced.md

This doc demonstrates a fenced code block holding a DELIBERATE example. The
scanner must ignore links and refs inside the fence.

```markdown
A sample broken link in docs: [x](./fenced-target.md)
And a sample backtick ref: `fenced/code.md`
```

The fence above is closed; this prose line is scanned normally again.
