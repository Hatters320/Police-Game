class_name ConsequenceEngine
extends RefCounted
## Stateless engine (matching IncidentProbabilityEngine/
## IncidentOutcomeEngine's shape) for the feature request's "Consequence &
## Simulation Engine": visible, probabilistic fallout from an incident
## being left to escalate, beyond the flat confidence hit
## IncidentManager._maybe_escalate already applies. "Not all missed
## incidents have to have a consequence -- AI can determine" is implemented
## as a straightforward probability roll rather than anything more
## elaborate, matching every other "AI-driven" system in this codebase
## (IncidentOutcomeEngine, DebriefScorer) being deterministic rule-based
## logic, not a live generative call.

## Chance, per escalation, that a second and more visible consequence
## lands on top of the flat confidence hit -- deliberately well under
## certain, so escalating doesn't always read as "and here's your
## punishment."
const CONSEQUENCE_CHANCE := 0.4

## Small extra confidence hit on top of the flat one _maybe_escalate
## already applies, only when this fires.
const EXTRA_CONFIDENCE_DELTA := -1.0

const CONSEQUENCE_FACTS := [
	"The delay meant the offender had already left before anyone arrived.",
	"Bystanders noted how long it took for a unit to attend.",
	"The situation was allowed to develop further than it needed to.",
]

## Returns {"applied": bool, "fact_text": String} -- if applied, the
## caller is expected to append fact_text to incident.known_facts (so it
## reads as part of the incident's real narrative, in the same "KNOWN"
## section round F's work already put front and centre) and the district's
## confidence has already been nudged by EXTRA_CONFIDENCE_DELTA here.
static func maybe_apply_escalation_consequence(
	incident: Incident,
	district: DistrictState,
	rng: RandomNumberGenerator,
) -> Dictionary:
	if rng.randf() >= CONSEQUENCE_CHANCE:
		return {"applied": false, "fact_text": ""}

	var fact_text: String = CONSEQUENCE_FACTS[rng.randi() % CONSEQUENCE_FACTS.size()]
	if not incident.known_facts.has(fact_text):
		incident.known_facts.append(fact_text)
	if district:
		district.apply_community_effect(EXTRA_CONFIDENCE_DELTA, 0.0)
	return {"applied": true, "fact_text": fact_text}
