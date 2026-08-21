class_name IncidentTypeFactory
extends RefCounted
## Builds the 5 incident types (of the 12+ in spec section 21) used by the
## small test map prototype: shoplifting, ASB, burglary, assault/fight,
## domestic incident. Built in code for the same reason as
## TestMapFactory -- no Godot editor available here to validate hand
## authored .tres files. Adding a 6th type later is a new static func here,
## not new engine code (spec section 59).

static func build_all() -> Array[IncidentTypeDefinition]:
	return [
		_shoplifting(),
		_asb(),
		_burglary(),
		_assault(),
		_domestic(),
	]

static func _shoplifting() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "shoplifting"
	def.display_name = "Shoplifting"
	def.base_threat = 10.0
	def.base_harm = 10.0
	def.base_vulnerability = 5.0
	def.base_immediacy = 15.0
	def.base_opportunity = 40.0
	def.base_rate_per_hour = 0.15
	def.district_weight_factors = {"theft_risk": 0.8, "police_visibility": -0.4}
	def.night_weighted = false
	def.possible_outcomes = [
		{"id": "offender_detained", "display_name": "Offender detained", "base_weight": 3.0, "favoured_skill": "response", "favoured_intent": GameEnums.CommandIntent.RESPOND},
		{"id": "offender_left_scene", "display_name": "Offender had left before arrival", "base_weight": 2.0},
		{"id": "evidence_gathered", "display_name": "Evidence gathered, no arrest", "base_weight": 1.5, "favoured_skill": "investigation"},
		{"id": "insufficient_evidence", "display_name": "Insufficient evidence", "base_weight": 1.0},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 2.0, GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 10.0, GameEnums.IncidentState.DEVELOPING: 5.0,
	}
	def.escalation_risk_per_minute = 0.005
	def.known_fact_templates = ["Store security reports a theft in progress", "Description of offender given"]
	def.unknown_fact_templates = ["Whether the offender is still in the area", "Value of goods taken"]
	def.primary_skill = "response" # catching an offender who may still be nearby
	return def

static func _asb() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "asb"
	def.display_name = "Anti-social behaviour"
	def.base_threat = 15.0
	def.base_harm = 10.0
	def.base_vulnerability = 15.0
	def.base_immediacy = 15.0
	def.base_opportunity = 10.0
	def.base_rate_per_hour = 0.2
	def.district_weight_factors = {"asb": 1.0, "night_economy": 0.5, "police_visibility": -0.5}
	def.night_weighted = true
	def.rain_multiplier = 0.6 # spec section 34: less outdoor loitering/gathering in the rain
	def.possible_outcomes = [
		{"id": "group_dispersed", "display_name": "Group dispersed", "base_weight": 3.0, "favoured_intent": GameEnums.CommandIntent.RESOLVE},
		{"id": "warning_given", "display_name": "Warning given", "base_weight": 2.0, "favoured_intent": GameEnums.CommandIntent.REASSURE},
		{"id": "group_relocated", "display_name": "Group relocated elsewhere", "base_weight": 1.5},
		{"id": "unresolved", "display_name": "Unresolved", "base_weight": 1.0},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 2.0, GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 12.0, GameEnums.IncidentState.DEVELOPING: 6.0,
	}
	def.escalation_risk_per_minute = 0.008
	def.known_fact_templates = ["Residents report a group causing a nuisance"]
	def.unknown_fact_templates = ["Number of people involved", "Whether alcohol is involved"]
	def.primary_skill = "community" # de-escalating and dispersing a group, not enforcement
	return def

static func _burglary() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "burglary"
	def.display_name = "Burglary"
	def.base_threat = 25.0
	def.base_harm = 30.0
	def.base_vulnerability = 25.0
	def.base_immediacy = 30.0
	def.base_opportunity = 15.0
	def.base_rate_per_hour = 0.06
	def.district_weight_factors = {"burglary_risk": 1.0, "police_visibility": -0.3}
	def.night_weighted = true
	def.possible_outcomes = [
		{"id": "suspect_identified", "display_name": "Suspect identified", "base_weight": 1.5, "favoured_skill": "investigation", "favoured_intent": GameEnums.CommandIntent.LOCATE},
		{"id": "evidence_gathered", "display_name": "Evidence gathered", "base_weight": 2.0, "favoured_skill": "investigation"},
		{"id": "no_suspect", "display_name": "No suspect identified", "base_weight": 2.5},
		{"id": "intelligence_created", "display_name": "Intelligence created", "base_weight": 1.0, "favoured_intent": GameEnums.CommandIntent.GATHER_INTELLIGENCE},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 3.0, GameEnums.IncidentState.ASSESSED: 2.0,
		GameEnums.IncidentState.ON_SCENE: 20.0, GameEnums.IncidentState.DEVELOPING: 10.0,
	}
	def.escalation_risk_per_minute = 0.004
	def.known_fact_templates = ["Forced entry reported", "Homeowner discovered the break-in on return"]
	def.unknown_fact_templates = ["Whether the offender is still on scene", "What was taken", "Point of entry"]
	def.recommended_specialist = GameEnums.SpecialistType.DOG # tracking a suspect who's fled the scene
	def.primary_skill = "investigation" # matches this type's own favoured_skill on its outcomes
	return def

static func _assault() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "assault"
	def.display_name = "Assault / fight"
	def.base_threat = 45.0
	def.base_harm = 45.0
	def.base_vulnerability = 25.0
	def.base_immediacy = 45.0
	def.base_opportunity = 5.0
	def.base_rate_per_hour = 0.08
	def.district_weight_factors = {"violence": 1.0, "night_economy": 0.6}
	def.night_weighted = true
	def.possible_outcomes = [
		{"id": "arrest_made", "display_name": "Arrest made", "base_weight": 2.0, "favoured_skill": "response", "favoured_intent": GameEnums.CommandIntent.RESPOND},
		{"id": "parties_separated", "display_name": "Parties separated", "base_weight": 2.5, "favoured_intent": GameEnums.CommandIntent.CONTAIN},
		{"id": "victim_taken_to_hospital", "display_name": "Victim taken to hospital", "base_weight": 1.0},
		{"id": "no_further_action", "display_name": "No further action", "base_weight": 1.0},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 1.0, GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 15.0, GameEnums.IncidentState.DEVELOPING: 8.0,
	}
	def.escalation_risk_per_minute = 0.02
	def.known_fact_templates = ["Caller reports a physical altercation"]
	def.unknown_fact_templates = ["Number of people involved", "Whether weapons are involved", "Injuries sustained"]
	def.recommended_specialist = GameEnums.SpecialistType.FIREARMS # violence in progress -- officer safety
	def.primary_skill = "response" # physical intervention, matches this type's own favoured_skill
	return def

static func _domestic() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "domestic"
	def.display_name = "Domestic incident"
	def.base_threat = 40.0
	def.base_harm = 35.0
	def.base_vulnerability = 45.0
	def.base_immediacy = 40.0
	def.base_opportunity = 0.0
	def.base_rate_per_hour = 0.05
	def.district_weight_factors = {"community_tension": 0.4, "vulnerability": 0.6}
	def.night_weighted = true
	def.possible_outcomes = [
		{"id": "arrest_made", "display_name": "Arrest made", "base_weight": 1.5, "favoured_intent": GameEnums.CommandIntent.RESPOND},
		{"id": "parties_separated_voluntary", "display_name": "Parties voluntarily separated", "base_weight": 2.0, "favoured_intent": GameEnums.CommandIntent.CONTAIN},
		{"id": "referred_to_support_services", "display_name": "Referred to support services", "base_weight": 2.0, "favoured_skill": "community", "favoured_intent": GameEnums.CommandIntent.REASSURE},
		{"id": "no_further_action", "display_name": "No further action", "base_weight": 1.0},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 1.0, GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 20.0, GameEnums.IncidentState.DEVELOPING: 10.0,
	}
	# Highest escalation risk of the five, deliberately -- spec section 29's
	# own worked example (verbal dispute -> threats -> violence -> injury)
	# is a domestic.
	def.escalation_risk_per_minute = 0.015
	def.known_fact_templates = ["Neighbour reports a loud argument"]
	def.unknown_fact_templates = ["Whether children are present", "Whether this is a repeat occurrence", "Current safety of parties"]
	def.primary_skill = "communication" # de-escalating parties, not enforcement-first
	return def
