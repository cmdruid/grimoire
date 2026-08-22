# `new <name>` · mint a founding-shaped working file

Mint only. No interview. Writes `./<name>.md` in cwd from
`templates/founding.md`. Legal inside an existing git repo — the working
file is the abort-costs-nothing rule; the repo is created only at `deploy`.

Not a records mint, even on a workshop host. The environment probe's
records-mint / output-home path does not apply (SKILL.md *Probe exemption*).

## Procedure

1. `<name>` is required. Never invent one. Missing → refuse: name the verb
   needs a filename.
2. Strip one trailing `.md` if present (`new foo.md` → stem `foo`, disk
   `foo.md`).
3. Reject if the stem is empty, `.`, or `..`, or contains `/` or `\`.
4. Refuse if `./<stem>.md` already exists. Do not overwrite.
5. Read `templates/founding.md` from this skill's own base directory. Write
   it to `./<stem>.md` with:
   - both `<date>` slots → today's date (`YYYY-MM-DD`)
   - the H1 `<name>` slot → the stem (a working title; grill may change it;
     it does not name the repo)
   - the six H2s left exactly as the template wrote them, each once
   - **empty** bodies — no coaching chrome, no interview

Output: that file only. Terminal step: stop. `grill` / `spec` fill it in
place when the user names it.
