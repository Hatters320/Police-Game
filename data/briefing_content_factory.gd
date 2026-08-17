class_name BriefingContentFactory
extends RefCounted
## Static flavour content for the pre-shift briefing (spec section 16):
## intelligence items, community issues, and information gaps. Real
## intelligence generated during play (IntelligenceManager.items) is
## shown alongside this on shift 2+, so briefings get genuinely more
## informed over time even though this starting flavour text never
## changes -- see docs/ARCHITECTURE.md's cross-shift persistence
## decisions.

static func starting_intelligence() -> Array[String]:
	return [
		"Repeat shoplifting reported at High Street retail units over the past fortnight.",
		"Residents around Northside Community Centre raising concerns about evening groups gathering.",
		"Vehicle crime pattern noted near the railway station car park.",
	]

static func community_issues() -> Array[String]:
	return [
		"East Estate residents' association requesting increased visible patrols.",
		"Ongoing noise complaints linked to the industrial estate's night shift traffic.",
	]

static func information_gaps() -> Array[String]:
	return [
		"No confirmed intelligence on who's behind the High Street thefts.",
		"Extent of the Northside gathering (numbers, regularity) not yet established.",
	]

## Free-form priority tags the player can pick up to 3 of at briefing (spec
## section 17). Tied to this build's actual test-map districts/locations
## so they mean something, not generic placeholders.
static func priority_options() -> Array[String]:
	return [
		"Town Centre disorder",
		"Northside ASB",
		"East Estate burglary",
		"Vehicle crime",
		"Community engagement",
		"Football match coverage",
	]
