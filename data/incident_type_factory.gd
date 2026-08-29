class_name IncidentTypeFactory
extends RefCounted
## Builds the 11 incident types (of the 12+ in spec section 21). Built in
## code for the same reason as TestMapFactory -- no Godot editor available
## here to validate hand-authored .tres files. Adding a type is a new
## static func here, not new engine code (spec section 59).
##
## Every type carries `time_band_multipliers`, so the mix of calls shifts
## across the day rather than the volume simply rising at night: fraud and
## workplace disputes are working-hours business, alcohol-related disorder
## and assaults peak in the evening, and burglary/robbery/vehicle crime and
## suspicious-activity calls belong to the small hours.
##
## `base_rate_per_hour` across all 11 was set by headless measurement, not
## by feel (see the README's round notes for the measurement). The
## target was to keep expected calls per 12-hour shift close to what the
## previous 5-type mix produced (~20), so going from 5 types to 11 changes
## *what* the player gets rather than simply doubling *how much*.

static func build_all() -> Array[IncidentTypeDefinition]:
	return [
		_shoplifting(),
		_asb(),
		_burglary(),
		_assault(),
		_domestic(),
		_fraud(),
		_workplace_incident(),
		_alcohol_disorder(),
		_robbery(),
		_vehicle_crime(),
		_suspicious_activity(),
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
	def.base_rate_per_hour = 0.13
	def.district_weight_factors = {"theft_risk": 0.8, "police_visibility": -0.4}
	# A shop-floor theft is reported while the shop is open.
	def.time_band_multipliers = {"business": 1.6, "evening": 1.0, "overnight": 0.3}
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
	def.base_rate_per_hour = 0.11
	def.district_weight_factors = {"asb": 1.0, "night_economy": 0.5, "police_visibility": -0.5}
	# Street disorder builds through the evening and carries into the night.
	def.time_band_multipliers = {"business": 0.5, "evening": 1.6, "overnight": 1.2}
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
	def.base_rate_per_hour = 0.05
	def.district_weight_factors = {"burglary_risk": 1.0, "police_visibility": -0.3}
	# Break-ins cluster overnight, when premises are empty and unwatched.
	def.time_band_multipliers = {"business": 0.6, "evening": 1.0, "overnight": 1.8}
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
	def.base_rate_per_hour = 0.06
	def.district_weight_factors = {"violence": 1.0, "night_economy": 0.6}
	# Violence tracks the night-time economy: peaks as venues fill and empty.
	def.time_band_multipliers = {"business": 0.5, "evening": 1.6, "overnight": 1.3}
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
	# Domestics peak in the evening once households are back together.
	def.time_band_multipliers = {"business": 0.5, "evening": 1.7, "overnight": 1.2}
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


## Working-hours acquisitive crime: reported by a business or a victim
## after the fact, so almost no immediacy and no realistic escalation --
## the value is in the investigation, which is why it sits on a long
## ON_SCENE and rewards an investigator.
static func _fraud() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "fraud"
	def.display_name = "Fraud report"
	def.base_threat = 5.0
	def.base_harm = 20.0
	def.base_vulnerability = 25.0
	def.base_immediacy = 5.0
	def.base_opportunity = 20.0
	def.base_rate_per_hour = 0.06
	def.district_weight_factors = {"theft_risk": 0.6, "vulnerability": 0.4}
	# Banks, businesses and victims report during office hours.
	def.time_band_multipliers = {"business": 1.7, "evening": 0.7, "overnight": 0.3}
	def.possible_outcomes = [
		{"id": "statement_taken", "display_name": "Statement taken, case filed", "base_weight": 3.0, "favoured_skill": "investigation"},
		{"id": "account_secured", "display_name": "Accounts secured, further loss prevented", "base_weight": 2.0, "favoured_skill": "investigation", "favoured_intent": GameEnums.CommandIntent.RESOLVE},
		{"id": "referred_to_action_fraud", "display_name": "Referred to national fraud reporting", "base_weight": 2.0},
		{"id": "victim_reassured", "display_name": "Victim safeguarded and reassured", "base_weight": 1.0, "favoured_skill": "communication", "favoured_intent": GameEnums.CommandIntent.REASSURE},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 4.0,
		GameEnums.IncidentState.ASSESSED: 3.0,
		GameEnums.IncidentState.ON_SCENE: 25.0,
		GameEnums.IncidentState.DEVELOPING: 8.0,
	}
	def.escalation_risk_per_minute = 0.001
	def.known_fact_templates = [
		"Victim reports money taken from their account",
		"Contact was made by phone and email",
	]
	def.unknown_fact_templates = [
		"Whether other victims have been targeted the same way",
		"Whether the funds can still be recalled",
	]
	def.primary_skill = "investigation"
	return def

## A dispute or injury at a business premises -- the daytime equivalent of
## a domestic: it is talked down rather than fought, hence communication.
static func _workplace_incident() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "workplace_incident"
	def.display_name = "Workplace incident"
	def.base_threat = 20.0
	def.base_harm = 25.0
	def.base_vulnerability = 15.0
	def.base_immediacy = 30.0
	def.base_opportunity = 15.0
	def.base_rate_per_hour = 0.05
	def.district_weight_factors = {"community_tension": 0.4, "traffic_activity": 0.2}
	# Only happens where there are people at work.
	def.time_band_multipliers = {"business": 1.9, "evening": 0.4, "overnight": 0.1}
	def.possible_outcomes = [
		{"id": "parties_separated", "display_name": "Parties separated, dispute defused", "base_weight": 3.0, "favoured_skill": "communication", "favoured_intent": GameEnums.CommandIntent.CONTAIN},
		{"id": "advice_given", "display_name": "Advice given to employer", "base_weight": 2.0, "favoured_skill": "communication"},
		{"id": "arrest_made", "display_name": "One party arrested", "base_weight": 1.0, "favoured_skill": "response", "favoured_intent": GameEnums.CommandIntent.RESPOND},
		{"id": "civil_matter", "display_name": "Recorded as a civil matter", "base_weight": 1.5},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 2.0,
		GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 14.0,
		GameEnums.IncidentState.DEVELOPING: 6.0,
	}
	def.escalation_risk_per_minute = 0.007
	def.known_fact_templates = [
		"Manager reports a dispute between two staff members",
		"Staff and customers are still on the premises",
	]
	def.unknown_fact_templates = [
		"Whether anyone has been injured",
		"Whether either party wants to make a complaint",
	]
	def.primary_skill = "communication"
	return def

## The evening's defining call: drink-related disorder around the
## night-time economy. Rain-suppressed like ASB -- people go home.
static func _alcohol_disorder() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "alcohol_disorder"
	def.display_name = "Alcohol-related disorder"
	def.base_threat = 30.0
	def.base_harm = 25.0
	def.base_vulnerability = 25.0
	def.base_immediacy = 40.0
	def.base_opportunity = 15.0
	def.base_rate_per_hour = 0.05
	def.district_weight_factors = {"night_economy": 0.9, "asb": 0.4, "police_visibility": -0.3}
	# Venues fill in the evening; the peak is before, not after, closing.
	def.time_band_multipliers = {"business": 0.2, "evening": 2.0, "overnight": 1.0}
	def.rain_multiplier = 0.7
	def.possible_outcomes = [
		{"id": "group_dispersed", "display_name": "Group dispersed without incident", "base_weight": 3.0, "favoured_skill": "community", "favoured_intent": GameEnums.CommandIntent.RESOLVE},
		{"id": "taken_home_safe", "display_name": "Vulnerable drinker got home safely", "base_weight": 2.0, "favoured_skill": "communication", "favoured_intent": GameEnums.CommandIntent.REASSURE},
		{"id": "arrest_made", "display_name": "Arrest for drunk and disorderly", "base_weight": 1.5, "favoured_skill": "response", "favoured_intent": GameEnums.CommandIntent.RESPOND},
		{"id": "venue_advised", "display_name": "Licensed venue advised", "base_weight": 1.5, "favoured_skill": "community"},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 2.0,
		GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 13.0,
		GameEnums.IncidentState.DEVELOPING: 7.0,
	}
	def.escalation_risk_per_minute = 0.012
	def.known_fact_templates = [
		"Door staff report a group refusing to leave",
		"Several people involved appear heavily intoxicated",
	]
	def.unknown_fact_templates = [
		"Whether anyone in the group is carrying anything",
		"Whether the argument started inside the venue",
	]
	def.primary_skill = "response"
	return def

## The most serious of the overnight acquisitive calls: theft with force.
## Highest escalation risk of the six new types -- a robbery left
## unattended is exactly the case the consequence engine should punish.
static func _robbery() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "robbery"
	def.display_name = "Robbery"
	def.base_threat = 55.0
	def.base_harm = 50.0
	def.base_vulnerability = 40.0
	def.base_immediacy = 55.0
	def.base_opportunity = 20.0
	def.base_rate_per_hour = 0.02
	def.district_weight_factors = {"theft_risk": 0.7, "violence": 0.5, "police_visibility": -0.3}
	# Street robbery belongs to the small hours and quiet streets.
	def.time_band_multipliers = {"business": 0.5, "evening": 1.0, "overnight": 1.8}
	def.possible_outcomes = [
		{"id": "suspect_detained", "display_name": "Suspect detained nearby", "base_weight": 1.5, "favoured_skill": "response", "favoured_intent": GameEnums.CommandIntent.RESPOND},
		{"id": "area_searched", "display_name": "Area searched, suspect not found", "base_weight": 2.5, "favoured_intent": GameEnums.CommandIntent.LOCATE},
		{"id": "victim_treated", "display_name": "Victim treated and safeguarded", "base_weight": 1.5, "favoured_skill": "communication"},
		{"id": "evidence_gathered", "display_name": "CCTV and evidence secured", "base_weight": 2.0, "favoured_skill": "investigation", "favoured_intent": GameEnums.CommandIntent.GATHER_INTELLIGENCE},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 1.0,
		GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 18.0,
		GameEnums.IncidentState.DEVELOPING: 10.0,
	}
	def.escalation_risk_per_minute = 0.022
	def.recommended_specialist = GameEnums.SpecialistType.DOG
	def.known_fact_templates = [
		"Victim reports being threatened and having property taken",
		"Suspect made off on foot moments ago",
	]
	def.unknown_fact_templates = [
		"Whether a weapon was actually seen",
		"Which direction the suspect went",
	]
	def.primary_skill = "response"
	return def

## Theft of and from vehicles. Finally gives DistrictState's
## `vehicle_crime_risk` -- carried since Milestone 1 -- something that
## actually reads it.
static func _vehicle_crime() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "vehicle_crime"
	def.display_name = "Vehicle crime"
	def.base_threat = 15.0
	def.base_harm = 20.0
	def.base_vulnerability = 10.0
	def.base_immediacy = 20.0
	def.base_opportunity = 30.0
	def.base_rate_per_hour = 0.05
	def.district_weight_factors = {"vehicle_crime_risk": 0.9, "police_visibility": -0.4}
	# Cars are left unattended overnight; so are the streets they're on.
	def.time_band_multipliers = {"business": 0.4, "evening": 0.9, "overnight": 1.9}
	def.possible_outcomes = [
		{"id": "suspect_disturbed", "display_name": "Suspect disturbed and made off", "base_weight": 2.5},
		{"id": "vehicle_recovered", "display_name": "Vehicle located and recovered", "base_weight": 1.5, "favoured_skill": "investigation", "favoured_intent": GameEnums.CommandIntent.LOCATE},
		{"id": "forensics_secured", "display_name": "Forensic opportunities secured", "base_weight": 2.0, "favoured_skill": "investigation"},
		{"id": "no_suspect", "display_name": "No suspect identified", "base_weight": 2.0},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 3.0,
		GameEnums.IncidentState.ASSESSED: 2.0,
		GameEnums.IncidentState.ON_SCENE: 16.0,
		GameEnums.IncidentState.DEVELOPING: 8.0,
	}
	def.escalation_risk_per_minute = 0.005
	def.recommended_specialist = GameEnums.SpecialistType.TRAFFIC
	def.known_fact_templates = [
		"Caller reports someone trying car door handles",
		"A vehicle window has been smashed",
	]
	def.unknown_fact_templates = [
		"Whether the vehicle has been taken or just entered",
		"Whether the suspect is still in the street",
	]
	def.primary_skill = "investigation"
	return def

## The low-severity overnight staple: a caller who has seen something they
## can't explain. Often nothing -- but it is how intelligence gets built,
## and ignoring every one of them has its own cost in confidence.
static func _suspicious_activity() -> IncidentTypeDefinition:
	var def := IncidentTypeDefinition.new()
	def.id = "suspicious_activity"
	def.display_name = "Suspicious activity"
	def.base_threat = 15.0
	def.base_harm = 10.0
	def.base_vulnerability = 15.0
	def.base_immediacy = 25.0
	def.base_opportunity = 25.0
	def.base_rate_per_hour = 0.05
	def.district_weight_factors = {"police_visibility": -0.4, "community_tension": 0.3, "burglary_risk": 0.4}
	# Reported when the street is quiet enough for something to stand out.
	def.time_band_multipliers = {"business": 0.5, "evening": 1.0, "overnight": 1.8}
	def.possible_outcomes = [
		{"id": "nothing_found", "display_name": "Area checked, nothing found", "base_weight": 3.0},
		{"id": "person_spoken_to", "display_name": "Person spoken to, accounted for", "base_weight": 2.0, "favoured_skill": "communication"},
		{"id": "intelligence_created", "display_name": "Intelligence report submitted", "base_weight": 2.0, "favoured_skill": "investigation", "favoured_intent": GameEnums.CommandIntent.GATHER_INTELLIGENCE},
		{"id": "caller_reassured", "display_name": "Caller reassured by patrol presence", "base_weight": 1.5, "favoured_skill": "community", "favoured_intent": GameEnums.CommandIntent.REASSURE},
	]
	def.state_durations = {
		GameEnums.IncidentState.REPORTED: 2.0,
		GameEnums.IncidentState.ASSESSED: 1.0,
		GameEnums.IncidentState.ON_SCENE: 9.0,
		GameEnums.IncidentState.DEVELOPING: 5.0,
	}
	def.escalation_risk_per_minute = 0.003
	def.known_fact_templates = [
		"Caller reports someone looking into parked cars",
		"A resident has seen a figure in a neighbour's garden",
	]
	def.unknown_fact_templates = [
		"Whether the person is still in the area",
		"Whether anything has actually been taken",
	]
	def.primary_skill = "investigation"
	return def
