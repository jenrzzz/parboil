# parboil — blog-idea incubator

Sparked 2026-07-11 from a live itch, not an old seed. Graduated from launchpad
the same day.

## The itch (user's words, near-verbatim)

> I've been saying I want to start a blog for several years now and keep
> thinking "hmmm that would be a cool thing to write about" but I struggle with
> actually sitting down to power through. What I think I'd really like is an
> outlining tool that kinda works like a mind map/graph thing with LLM assists,
> so it helps me build momentum from the seed of the idea to something that's
> actually fleshed out enough to draft.

## Reframe from first brainstorm

The stated ask is an outlining/mind-map tool. The actual problem is
**activation energy**, at three distinct points:

1. **Capture** — ideas strike away from the desk and evaporate.
2. **Re-entry** — opening a half-formed idea and not knowing where to start is
   the blank-page problem all over again.
3. **No finish line** — "fleshed out enough to draft" is undefined, so no
   session ever feels done.

The mind map is a *view*, not the mechanism. The mechanism is an **interview**:
the LLM asks pointed questions, the user answers (talking about your idea is
easy; arranging boxes on a canvas is not), and typed nodes are extracted from
the answers into the idea's graph as a byproduct.

## Proposed shape (v1 sketch)

- One idea = one interview conversation + a typed graph extracted from it.
  Node types: `claim`, `example`, `question` (open/answered), `counterpoint`,
  `reference`, `hook`.
- **Re-entry ritual**: opening an idea shows a recap of the graph so far plus
  exactly ONE next question. Session commitment = answer one question.
- **Ripeness**: coverage checklist per idea (thesis stated, audience named,
  ≥3 concrete examples, strongest counterargument addressed, opening hook
  exists) → visible "draft-ready" state. This is the finish line.
- **Linearize**: one action orders the graph into a markdown outline —
  headings + the user's own bullets — exported as the handoff artifact to
  whatever editor the actual drafting happens in.

## The dogmatic rule

**The LLM never writes prose for the post.** It asks questions, names gaps,
proposes orderings, and summarizes what *you* said. The moment it drafts
sentences, the voice dies and the blog stops being yours. Drafting-for-you is
the seductive anti-feature — it is what every other LLM writing tool does, and
it is explicitly out of scope at every version.

Hence the name: parboil cooks the idea *partway*, deliberately — finishing
happens by another method (you, drafting). gem=404, npm=404, pypi=200
(pypi collision fine for a Rails app). Runner-up name: **stoke** (gem=404).

## Fleet grounding

- **Near-client of hob**: interviewer persona, branched conversation, idea
  graphs as realm-scoped memory entities. knowbee was already absorbed into
  hob's memory plane; this overlaps hard. hob is design-phase, so: build v1
  behind a hob-shaped gateway interface, direct Claude call underneath until
  hob's gateway is real. parboil is useful first-client pressure on hob's
  design. Verified against `~/Source/hob/DESIGN.md` 2026-07-11:
  - hob really is design-phase — the repo holds DESIGN.md plus a stub ruby
    client gem (`hob` 0.0.1, name already grabbed on rubygems).
  - The interface to mimic is the hob client shape:
    `hob.complete(role:, schema:, messages:)` for typed-node extraction,
    `hob.chat(conversation:, branch:, persona:, context:) { |event| }` for
    the interview turn. Build parboil's internal gateway to exactly that
    signature so the eventual swap is a client-library change, not a rewrite.
  - **Model roles, not model IDs**: parboil asks for roles (e.g.
    `interviewer`, `cheap-classifier` for extraction), maps them to concrete
    Claude models in its own config for now — that mapping is what hob
    replaces.
  - Timing lines up: personas + conversation DAG are hob v1, but the memory
    entity graph is hob **v3** — parboil's cross-idea connections are also
    parboil v3, so nothing in parboil v1/v2 waits on hob.
  - Realm: this is public-identity blog work → `personal` clearance (not
    `intimate`).
- **Proven patterns to lift**: kat's MessageNode DAG + LLM tool loops (chat
  that emits structured output); feedcurator's tool-call structured output.
- **Capture channel**: mail-as-input à la KTN (`seed@…` alias on an existing
  mail cluster) — v2.
- **Endpoint**: the blog itself doesn't exist yet. jfave-web (static sites,
  one Caddy container) is the natural home; publish pipeline is v3.
- **Deploy**: golden path, gated tier (Authelia), jfave.com zone (this is
  public-identity work).

## Sequencing (cut lines)

- **v1 (razor-thin)**: single idea lifecycle — seed → interview → typed node
  extraction → linearize → markdown outline export. Graph "view" is a nested
  list. No canvas, no email capture, no ripeness meter. Rails, per house
  pattern.
- **v2**: read-only graph render (click-to-focus, no editing), ripeness
  checklist, email capture, "what's simmering" garden view across ideas.
- **v3**: publish script to jfave-web; cross-idea connections (where hob's
  memory graph earns its keep); maybe voice capture.
- **Do NOT build first**: interactive canvas editor (UI tar pit), LLM
  drafting (banned forever, see above).

## Decisions (2026-07-11)

- Name confirmed: **parboil**.
- Drafting happens in **neovim**, locally. parboil does not integrate with the
  editor — it just makes the linearized outline trivially pullable (curl an
  endpoint or a tiny CLI wrapper). The whole draft loop is terminal-side.
- Publish target is **jfave-web** via a **script**, not a web pipeline:
  finished markdown → static post in the jfave-web repo → push to master →
  Coolify redeploys (the existing jfave-web pattern). Implies picking a static
  generator (or plain templated HTML) inside jfave-web — that's a jfave-web
  decision, not a parboil one; parboil's contract ends at "markdown file with
  frontmatter."
- Distribution is a **docker image** (the golden-path deploy), not a gem — no
  package names to register anywhere. The earlier gem/npm availability checks
  were just name-collision hygiene, not a reservation plan.

## Open questions

- ~~Does the interviewer persona live in hob's persona system or stay local
  until hob ships?~~ Resolved 2026-07-11: local. hob v1 includes personas but
  isn't built; parboil keeps the persona as local prompt material shaped like
  hob's (system core + example dialogue), migrating when hob's persona system
  exists.
- Interview style: one fixed persona, or selectable stances (skeptic,
  enthusiast, editor)?
- Static generator choice for jfave-web posts (out of parboil's scope, but
  blocks the publish script).
