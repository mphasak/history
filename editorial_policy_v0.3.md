# Editorial Policy v0.3 — Perspective Admission and Governance

> The Human History Simulator differs from Wikipedia in one structural way: instead of
> forcing every topic toward a single neutral-point-of-view article, it carries multiple
> co-existing Perspectives and renders them side-by-side. This solves the edit-war problem
> at the cost of creating a new one: **what counts as a legitimate Perspective?** This
> document specifies the bar a Perspective must clear to be admitted, the bar that gets
> it rejected, the editorial structure that enforces those bars, and the within-Perspective
> rules that govern day-to-day editing.

---

## 1. The two-layer governance model

The system has two governance layers operating on different objects under different rules.

**Layer 1 — Within-Perspective editing (Wikipedia-like).** Once a Perspective is admitted,
edits to its endorsed claims, asserted lineages, and source weights are crowdsourced and
follow standard wiki rules: cite sources, discuss before reverting, build consensus among
that Perspective's contributor community. Edit wars stay scoped to one Perspective — they
don't spill across. This is the boring, well-understood layer.

**Layer 2 — Cross-Perspective admission (editorial-board-controlled).** The decision to
admit a new Perspective is *not* crowdsourced. A small editorial board reviews proposed
Perspectives against the criteria in §3 below and votes. The board's job is gatekeeping
the methodology bar, not adjudicating between admitted Perspectives. Once two Perspectives
are both admitted, the board has nothing further to say about which one is "right" — the
system just renders both.

This split is deliberate. Crowdsourcing within a coherent worldview works (the Catholic
encyclopedia and the Marxist encyclopedia can each be well-edited internally). Crowdsourcing
the *admission* of worldviews does not work — every fringe community would vote in its own
worldview and the system would fill with noise.

---

## 2. What a Perspective is, in policy terms

A Perspective is a structured object with required fields (per the schema):

- A `display_name` and `summary` written from the inside — the Perspective's own
  self-description, not someone else's characterization of it.
- `proponents` — at least one named scholar, intellectual tradition, religious community,
  or political-philosophical lineage that holds this view, with citations to where it has
  been articulated in the open literature.
- `methodology_notes` — explicit description of what this Perspective privileges in
  evidence, what it explicitly rejects, and what its acknowledged blind spots are.
- A `domain_scope` — which trait domains this Perspective makes claims about. A genetic
  Perspective need not have opinions about Renaissance painting.
- A non-empty set of `perspective_endorsements` differentiating it from existing
  Perspectives. A Perspective that endorses every default claim and asserts no new ones
  contributes nothing and should be rejected as redundant.

A Perspective is *not* a person, a website, a social-media community, or a political party.
It is an articulated intellectual position. "What r/<subreddit> believes about X" is not
a Perspective. "What Christopher Caldwell, in *The Age of Entitlement*, argues about US
political realignment" is.

---

## 3. Admission criteria

A proposed Perspective is admitted if and only if it meets **all** of the following tests.

### 3.1 The proponent test

The Perspective must be held by identifiable proponents whose articulation of it is
public and citable. Acceptable proponent types:

- Scholars publishing in peer-reviewed venues, university press monographs, or recognized
  scholarly book series.
- Intellectual traditions with a documented history (e.g., Thomism, Marxist historiography,
  classical liberalism, Vedic-textual indigenism). The tradition itself is the proponent;
  individual contemporary voices anchor it.
- Religious communities with formal doctrinal positions and citable canonical or magisterial
  texts.
- Established think tanks and policy institutes with peer review or editorial standards
  (note: *established*, not self-declared — see §4).

Unacceptable: anonymous online communities, individual bloggers without scholarly track
record, self-published works without citation footprint, or proponent claims that cannot
be verified against published material.

The bar is intentionally porous to non-academic traditions. Indian indigenist scholarship,
oral-historical traditions of Indigenous communities, and confessional religious
historiography all clear it. The bar excludes positions whose only proponents are an
anonymous user base or a single self-publishing individual.

### 3.2 The transparency test

The Perspective must declare:

- What sources it weights highly and why.
- What sources it weights low or excludes and why.
- Its methodological commitments (e.g., "privileges archaeological continuity over
  linguistic reconstruction," "treats Vedic chronology as evidence on par with radiocarbon
  dates," "treats peer-reviewed political-history literature as primary").
- Its acknowledged blind spots and weakest claims.

A Perspective that refuses to articulate its commitments — that claims to be just "the
truth" — fails this test. Every admitted Perspective wears its priors visibly.

### 3.3 The empirical-floor test

A Perspective may not assert factual claims that contradict empirically settled science
where settlement is not itself contested across reasonable Perspectives. Concretely:

- It may not deny the age of the Earth, the fact of biological evolution, the reality of
  the Holocaust, the occurrence of well-documented historical events with overwhelming
  primary-source corroboration, or established physical laws.
- It may not assert facts that depend on the falsification of well-replicated empirical
  results (e.g., "humans and dinosaurs co-existed").
- It *may* dispute the **interpretation** of empirical findings (e.g., the Out-of-India
  Perspective accepts the qpAdm Steppe ancestry signal but disputes its timing,
  directionality, and cultural-linguistic interpretation — that's interpretation, not
  fact-denial).

The line between "interpretation" and "fact-denial" is genuinely hard at the margins. The
editorial board's job is to draw it case-by-case, in writing, with reasoning published.
Section 5 below gives worked examples.

### 3.4 The differentiation test

The Perspective must materially differ from already-admitted Perspectives. A new
Perspective that endorses an existing one's claims wholesale is not a Perspective; it's
an alias, and should be merged. A new Perspective that disagrees on one minor point should
be filed as a `nuances` endorsement on the existing Perspective, not as a new top-level
Perspective.

The threshold: a new Perspective must contribute **at least one substantively different
endorsement on a non-trivial claim**, ideally several, ideally clustered around a coherent
methodological or interpretive disagreement.

### 3.5 The non-targeting test

A Perspective may not be defined primarily by hostility to a group of people (rather than
to a position). "What conservatives think about X" is admissible because it specifies an
intellectual tradition. "What a particular ethnic group really believes" framed
essentialistically is not. The distinction matters because the system displays Perspective
attributions prominently; we don't want to platform Perspectives whose primary purpose is
to caricature an outgroup.

---

## 4. Disqualifying patterns

Some classes of proposed Perspective are rejected categorically. Listing them explicitly
prevents the editorial board from re-litigating each instance.

**Holocaust denial and analogous denialisms.** These fail the empirical-floor test (§3.3).
The historicity of the Holocaust is settled by overwhelming convergent primary evidence;
denial is not a "perspective on" that evidence, it is a refusal to engage with it. Same
class: denial of Indigenous American depopulation post-contact, denial of Atlantic slave
trade scale, denial of large-scale documented genocides.

**Hyperdiffusionism without evidentiary discipline.** Hancock-style "lost civilization"
narratives that posit advanced pre-Holocene global cultures fail the proponent test (§3.1)
when they lack scholarly proponents and fail the transparency test (§3.2) when they don't
declare their methodology. *This is not the same as rejecting all heterodox archaeological
claims* — Renfrew's Anatolian hypothesis for Indo-European origins is heterodox but clears
all four tests and is admissible.

**Race science / scientific racism.** Claims that group differences in any contested
behavioral or social outcome are predominantly genetic in origin fail the empirical-floor
test where scientific consensus exists, and fail the non-targeting test where the
Perspective's primary effect is to argue for the inferiority of a group. The harder cases
involve population genetics findings that have legitimate scholarly status but get weaponized;
the policy here is to accept the underlying findings as Claims (with full source support)
and reject Perspectives whose distinctive contribution is the inferiority interpretation.

**Single-author conspiracy theories.** A Perspective held by one individual, lacking a
broader intellectual tradition or scholarly footprint, fails the proponent test even if
that individual is articulate.

**State propaganda framings without independent scholarly correlate.** A government's
official line on a contested historical event does not, by itself, constitute a
Perspective. It does count as a Source within other Perspectives that engage with it.
The line is fuzzy: the Soviet historiographical tradition has both state-propaganda and
genuine-scholarship elements; the editorial board treats the scholarly tradition as
admissible and treats specific propaganda artifacts as Sources within it.

---

## 5. Worked examples

The following are decisions the editorial board would render under the policy as written.
They're included so future board members and prospective Perspective proposers can see
how the criteria apply.

**Out-of-India / Indigenous Aryan (PERSP_INDIAN_OOI) — ADMIT.** Has identifiable scholarly
proponents (Talageri, Kazanas, parts of the Indian archaeological tradition); transparent
about its methodological commitments (privileging Vedic chronology, archaeological
continuity); reinterprets rather than denies the qpAdm Steppe signal; differs materially
from PERSP_INDIAN_AMT. Some board members will think it's wrong. That doesn't matter — the
job is to assess whether it clears the methodology bar, not whether it's correct.

**Renfrew Anatolian-hypothesis Indo-European origins — ADMIT (when proposed).** Heterodox
within current ancient-DNA-era scholarship but a serious academic position with extensive
publication history. Clears all tests. Would be admitted as e.g. PERSP_RENFREW_ANATOLIAN.

**Hancockian hyperdiffusionism — REJECT.** Fails the proponent test (no scholarly
proponents in archaeology) and the empirical-floor test (asserts pre-Holocene advanced
civilizations against the radiocarbon and stratigraphic record).

**Holocaust denial — REJECT.** Fails the empirical-floor test categorically.

**"MAGA-as-fascist-provenance" reading (Paxton-Stanley-Hofstadter lineage) — ADMIT** as
PERSP_IDEO_ACADEMIC_MAINSTREAM_LEFT or similar. Clears all four tests. Identifiable
academic proponents, transparent methodology, doesn't violate empirical-floor (it's an
interpretive reading), differs from other admitted Perspectives.

**"MAGA-as-Jacksonian-realignment" reading (Caldwell-Continetti tradition) — ADMIT** as
PERSP_IDEO_CONSERVATIVE_INTELLECTUAL or similar. Clears all four tests for the same
reasons. The system renders both, side-by-side or in diff overlay; the board does not
adjudicate which is correct.

**Catholic continuity reading of Christian history — ADMIT** as
PERSP_CHURCH_HISTORY_CATHOLIC. Identifiable proponents (the Magisterium, Catholic
historians), transparent (privileges magisterial documents, apostolic-succession arguments),
empirical-floor compliant, differs from Protestant-break readings.

**Indigenous oral-historical Perspectives on pre-contact Americas — ADMIT** when proposed
by community-recognized knowledge-holders or Indigenous-studies scholars. Clears the
proponent test (oral tradition with identifiable bearers), the transparency test (must
articulate which traditions, which knowledge-holders, what the standards of reliability
are within those traditions). Empirical-floor: oral traditions can disagree with the
archaeological record on specifics; the policy treats this as interpretation-disagreement,
not fact-denial, when the underlying empirical record is itself thin or contested.

**"Soviet historiography of WWII" — TWO-PART DECISION.** The scholarly tradition that
emerged from Soviet and post-Soviet historians (Roy Medvedev, Volkogonov, contemporary
Russian academic historians) is admissible as PERSP_SOVIET_RUSSIAN_HISTORIOGRAPHY. Specific
state-propaganda artifacts (e.g., the canonical Stalin-era line on Katyń) fail as
Perspectives but appear as Sources within other Perspectives that engage with them.

---

## 6. Editorial board structure

The editorial board is the body that applies §3 and §4. Its design matters because the
whole system's credibility rides on it.

**Composition.** Initial size 5–9 members. Members serve staggered three-year terms.
Composition aims for diversity along three axes:

- **Disciplinary** — at least one geneticist, one archaeologist, one historian, one
  political scientist or sociologist, one philosopher of science or epistemologist.
- **Geographic and intellectual-tradition** — explicit effort to include non-Western
  scholarly traditions (Indian, Chinese, African, Indigenous-American studies). Without
  this the policy will systematically under-admit non-Western Perspectives even when they
  meet the criteria.
- **Methodological** — at least one member from a quantitative-empirical tradition and
  one from a hermeneutic-interpretive tradition, because the empirical-floor test
  requires both sensibilities to apply correctly.

**Selection.** Founder seats the initial board with public reasoning. Subsequent members
are nominated by the sitting board with a public comment period and approved by
two-thirds vote. No anonymous members. No unrecused conflicts of interest with
Perspectives under review.

**Decisions.** Admission requires simple majority. Rejection requires the same. Board
must publish written reasoning for every decision, citing the specific tests in §3 or §4
that the proposal cleared or failed. Decisions are appealable once; second appeals require
new evidence.

**Removal of admitted Perspectives.** A previously-admitted Perspective may be moved to
`retired` status if subsequent evidence makes it untenable (e.g., a Perspective resting
on a study that was later retracted). The bar for retirement is higher than the bar for
admission — two-thirds vote and published reasoning. A retired Perspective remains
visible in the system but is rendered with a deprecation notice.

**Term limits and rotation.** No member serves more than two consecutive terms. This is
to prevent the board from calcifying around a particular taste in Perspectives.

---

## 7. Within-Perspective editing rules

Once a Perspective is admitted, day-to-day editing of its endorsements operates under
standard wiki-style rules:

1. **Cite or get reverted.** Any new endorsement, asserted relation, or override must
   reference at least one Source. Endorsements without sources are reverted on sight.
2. **Discuss before reverting contested edits.** Each Perspective has a talk page;
   substantive disagreements go there before edits.
3. **Three-revert rule.** No editor reverts the same edit more than three times in 24
   hours; persistent disputes go to the Perspective's contributor community for consensus.
4. **Perspective scope is binding.** An editor working on PERSP_INDIAN_AMT cannot push
   that Perspective's claims into endorsements that contradict its declared methodology.
   If their view has drifted, they should propose a fork as a new Perspective rather than
   silently changing an existing one.
5. **Provenance preserved.** Every edit is recorded in `edit` (per schema §3.13) with the
   Perspective context, before/after, and editor identity. No edits are anonymous.
6. **Sources held to source standards, not Perspective standards.** A Source is admitted
   into the system if it's a legitimate citable artifact (a published paper, a recognized
   text, a dataset). Different Perspectives may weight it differently, but its admission
   as a Source is not gated by Perspective.

---

## 8. Forks

Forking is a first-class operation. If a contributor community within an admitted
Perspective splits over a substantive question, the minority can fork: a new Perspective
inheriting the parent's endorsements, with the disputed claims overridden. The forked
Perspective goes through the standard admission process; the parent is unaffected.

This is deliberately easier than what Wikipedia allows, and it's the system's primary
release valve. If editorial disagreement gets heated, the system says "fine, fork it"
rather than forcing resolution. The cost is a proliferation of Perspectives; the benefit
is that internal coercion is replaced by external comparison.

---

## 9. Things this policy deliberately does not do

- **It does not adjudicate between admitted Perspectives.** Once two Perspectives clear
  the bar, the system renders both with equal visual weight. The board has no opinion on
  which is correct, and the UI never presents one as default-true.
- **It does not require scholarly consensus.** A Perspective that almost everyone in a
  field rejects can still be admitted if it clears the four tests. Scientific disputes
  often turn out the dissenters were right; the policy is designed to leave room for that.
- **It does not require political neutrality from individual Perspectives.** Perspectives
  are explicitly partisan in many cases (PERSP_IDEO_LIBERTARIAN is libertarian; that's the
  point). Neutrality lives in the system's *aggregate*, not in any individual Perspective.
- **It does not promise the policy is final.** This document will be revised as the
  editorial board encounters edge cases the criteria don't cleanly handle. Revisions are
  themselves public and reasoned.

---

## 10. Open issues for v0.4

Things this draft punts on, to be resolved before launch:

1. **Funding and conflicts.** Who pays the editorial board? How are conflicts disclosed?
   A Perspective whose proponents fund the board is a structural problem.
2. **Jurisdiction.** Some claims (notably about ongoing political conflicts) have legal
   exposure in some jurisdictions and not others. Does the system geo-fence content?
   What's the policy on government takedown requests?
3. **Rate of change.** Some Perspectives (post-2018 ancient DNA consensus) revise
   monthly; others (Catholic doctrinal history) revise on geological timescales. The
   talk-page and revert workflow needs to handle both without making either feel weird.
4. **Aggregating across Perspectives.** When the UI shows "confidence 4/5," confidence
   relative to what Perspective set? The current draft says per-Perspective-set, but the
   default landing experience needs a defined Perspective set, and choosing it is itself
   editorial.
5. **Perspectives held by living political movements.** When the proponents are an active
   political faction (rather than a settled scholarly tradition), the editorial board has
   to decide whether self-articulation by movement intellectuals counts as proponent
   citation. Current draft says yes if they have published work meeting normal
   citation standards. Edge cases will test this.
