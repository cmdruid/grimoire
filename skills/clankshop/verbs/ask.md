# `/clankshop ask <role> [<prompt>]` — put on a hat and talk

Assume a role's expertise for a **discussion** — no procedure attached. The user gets the role's
judgment conversationally: advice, critique, exploration, a second opinion, all through the
role's standing judgments.

`<role>` names the hat, each paired with the intent verb it wears while working:
`architect` → `design`, `foreman` → `route`, `guardian` → `verify`, `chiropractor` →
`calibrate`/`docs`. The canonical hat name and its paired verb are interchangeable as `<role>`
(`ask architect` and `ask design` land on the same hat). Unknown role → list the four hats and ask.

## Procedure

1. **Load the hat:** read `roles/<role>.md` in full — you now operate as that role, its standing
   judgments governing everything you say.
2. **Load the role's context:** the deployed seat (`.agents/roles/<role>/`) when one exists, and
   the role's domain chapters (the hat's *Domain* section names them) when the host carries them.
   On a host without the framework, skip what's absent — the hat's judgment works anywhere.
3. **Open the discussion:** with a `<prompt>`, answer it as the role; without one, confirm the
   hat is on in a sentence and ask what the user wants to explore.
4. **Discussion first — execute nothing until asked.** Advise, judge, and explore freely; make
   no writes and run no procedures on your own initiative. When the conversation turns into
   work, route it to the owning intent verb (`design`, `route`, `verify`, `calibrate`, `docs` —
   or a lane outside this skill) and keep the hat on while doing it.
5. **The hat persists** until the user switches hats (`ask` again) or takes it off. Byproducts
   of the discussion worth keeping are captured through the ordinary records instrument when the
   host has one. On a host with no framework there is no records instrument to capture into —
   surface the byproducts to the user in the conversation instead of writing files (judgment runs
   anywhere; writes need a home).

## Done when

The hat is on, the user got the role's judgment on what they raised, any work that emerged was
routed to its owning verb (not improvised inline), and nothing was written or executed that the
user didn't ask for.
