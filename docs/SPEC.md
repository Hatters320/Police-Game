WESTFORD
POLICE COMMAND SIMULATOR

MVP GAME DESIGN + TECHNICAL BUILD SPECIFICATION
VERSION 0.1

============================================================
1. PROJECT OBJECTIVE
============================================================

Build a playable MVP of a police command/management simulation game called:

WESTFORD

The player takes the role of a UK police Inspector responsible for managing a frontline response team during 10–12 hour operational shifts.

The player does NOT play as an individual police officer.

The player is the operational commander.

The player observes a living town from an overhead/isometric 2D map and must:

- assess available resources
- conduct a shift briefing
- set priorities
- position police resources
- respond to incoming incidents
- decide which officers/resources to deploy
- manage competing incidents
- manage fatigue and breaks
- use neighbourhood resources
- request specialist resources
- react to planned events
- manage limited resources
- deal with incomplete information
- monitor community issues
- make decisions whose consequences affect the rest of the shift
- complete the shift
- receive an end-of-shift operational debrief

The central gameplay concept is:

"Manage a constantly changing policing environment with fewer resources than you would ideally like to have."

The game should feel like a mixture of:

- SimCity-style living town
- real-time strategy
- resource management
- management simulation
- incident response
- emergent storytelling

It should NOT feel like:

- a spreadsheet
- a simple dispatch simulator
- a clicker game
- a first-person police game
- a traditional RPG
- a city-building game

The player controls policing resources within an already-established town.

The town itself is NOT built by the player in the MVP.


============================================================
2. IMPORTANT DEVELOPMENT PHILOSOPHY
============================================================

The MVP must prove ONE thing:

IS MANAGING A 10–12 HOUR POLICE SHIFT FUN?

Do not attempt to build the entire long-term game during the MVP.

Do NOT implement unless specifically requested:

- multiple cities
- promotions
- multiplayer
- online accounts
- monetisation
- advertisements
- purchases
- persistent cloud saves
- procedural city generation
- 3D graphics
- building interiors
- first-person gameplay
- detailed police radio simulation
- voice acting
- complex crime investigation system
- court system
- custody management
- advanced personnel HR system
- full criminal AI
- realistic driving physics
- hundreds of individually simulated citizens
- major incident command
- terrorism simulation
- firearms tactics
- advanced weapon systems
- real police force branding
- real police data

The architecture SHOULD allow these systems to be added later.

Do not build them now.

If a feature is not required to prove the core gameplay loop, leave it out.


============================================================
3. TECHNOLOGY
============================================================

Preferred engine:

GODOT 4.x

Preferred approach:

2D game with an isometric/angled visual presentation.

The game should be designed primarily for mobile/touch interaction but should also be usable with mouse input during development.

The simulation engine must be separated from presentation/UI.

Do not hard-code simulation logic directly into visual nodes where avoidable.

Recommended conceptual architecture:

SIMULATION
    |
    +-- GameClock
    +-- DistrictManager
    +-- ResourceManager
    +-- OfficerManager
    +-- VehicleManager
    +-- IncidentManager
    +-- EventManager
    +-- IntelligenceManager
    +-- FatigueManager
    +-- CommunityManager
    +-- ShiftManager
    |
    v
WORLD
    |
    +-- Roads
    +-- Buildings
    +-- Locations
    +-- Districts
    |
    v
PRESENTATION
    |
    +-- Map
    +-- Police vehicles
    +-- Incident markers
    +-- UI
    +-- Notifications
    +-- Panels


============================================================
4. CORE GAME LOOP
============================================================

The complete MVP gameplay loop is:

1. Start shift
2. Receive staffing picture
3. Review intelligence
4. Review planned events
5. Review community issues
6. Review information gaps
7. Set operational priorities
8. Allocate available resources
9. Set patrol locations
10. Set proactive tasks
11. Set response reserve
12. Start simulation
13. Observe Westford
14. Receive incidents
15. Assess incidents
16. Deploy resources
17. Monitor incidents
18. React to escalation
19. Reallocate resources
20. Manage fatigue/breaks
21. Monitor district conditions
22. Complete shift
23. Receive operational debrief
24. Start next shift

The player should continually move between:

OBSERVE
    ->
ASSESS
    ->
DECIDE
    ->
DEPLOY
    ->
OBSERVE CONSEQUENCES
    ->
REASSESS


============================================================
5. THE WORLD — WESTFORD
============================================================

Westford is a fictional UK town.

It is not based on a specific real police force.

Initial population target:

Approximately 30,000–40,000 people.

The town should visually appear complete and established.

The player does not build the town.

The town exists before the player begins.

The map should contain:

- residential areas
- town centre
- high street
- retail area
- railway station
- industrial estate
- school
- secondary school
- community centre
- hospital
- police station
- fire station
- football stadium
- pubs
- restaurants
- supermarkets
- small shops
- parks
- estates
- rural outskirts
- main roads
- minor roads
- car parks
- petrol station

The map should have approximately 6 meaningful districts.

Suggested districts:

1. Town Centre
2. Northside
3. East Estate
4. South Residential
5. West Industrial
6. Rural/Outskirts

The names can be changed if better names are suggested.

The town should feel visually alive but the MVP does NOT need to individually simulate every citizen.


============================================================
6. DISTRICT SYSTEM
============================================================

Every district has hidden simulation variables.

Initial variables:

- ASB level
- violence level
- burglary risk
- vehicle crime risk
- theft risk
- community tension
- vulnerability
- police visibility
- traffic activity
- night-time economy activity
- intelligence quality
- recent incident pressure

Each variable should normally be represented internally on a 0–100 scale.

The player should NOT necessarily see all values directly.

Some information should be hidden or represented through intelligence.

Example:

Internal state:

East Estate
ASB = 72
Community tension = 55
Police visibility = 20
Intelligence quality = 35

The player may only see:

"Residents report increasing youth disorder around the community centre."

This means intelligence gathering has genuine gameplay value.


============================================================
7. INITIAL WESTFORD CRIME/DEMAND PROFILE
============================================================

The starting game should contain relatively low-level problems.

Do not begin with extreme crime.

Initial common demand should include:

- shoplifting
- street drinking
- ASB
- rowdy behaviour
- night-time economy disorder
- occasional burglary
- street robbery
- theft from motor vehicles
- parking issues
- neighbour disputes
- welfare concerns
- missing persons
- road collisions
- suspicious activity

Major incidents should be rare.

The first few shifts should teach the player the system.


============================================================
8. POLICE STAFFING MODEL
============================================================

Small-town response team:

Nominal establishment:

16 officers

Typical available staffing:

Approximately 10–13 officers.

Minimum operational staffing:

10 officers.

The game should regularly operate at or close to minimum staffing.

Staffing can be reduced by:

- annual leave
- sickness
- training
- other duties

Example:

Establishment = 16

Annual leave = 2

Training = 1

Sickness = 1

Available = 12

Minimum = 10

This should create realistic resource pressure.


============================================================
9. SUPERVISION
============================================================

Small-town response team should normally have:

2 Sergeants.

The Inspector can task the Sergeants.

Sergeants may themselves become committed to incidents.

Supervisors should be represented as resources.

A supervisor may be required for:

- difficult incidents
- officer support
- developing incidents
- incidents involving inexperienced officers

The MVP does not require a complex supervisory AI system.

Simple rules are sufficient.


============================================================
10. NEIGHBOURHOOD TEAM
============================================================

Neighbourhood officers should exist separately from the main response team.

Typical availability:

2–4 officers.

Neighbourhood officers generally do not work overnight in the MVP.

The Inspector can request/task neighbourhood officers.

However:

Neighbourhood officers have competing demands.

Therefore requesting them should not be completely free.

Possible states:

- available
- community engagement
- proactive task
- existing neighbourhood task
- unavailable

Neighbourhood officers should be particularly useful for:

- community engagement
- intelligence gathering
- ASB problems
- reassurance
- problem-solving tasks


============================================================
11. SPECIALIST RESOURCES
============================================================

The small-town Inspector should NOT have permanent access to all specialist resources.

Specialist resources can include:

- traffic
- dog
- firearms

The MVP should contain:

1 traffic unit
1 dog unit
1 firearms unit

These units operate across a wider simulated area.

They may be:

- available
- committed
- unavailable
- nearby
- far away

The player can request them.

They are NOT guaranteed.

Travel time should matter.

For MVP purposes, specialist units can be represented as external resources with simplified behaviour.


============================================================
12. VEHICLE / CREW MODEL
============================================================

The team may have enough vehicles on paper for the available officers.

However, not every officer can necessarily drive.

Therefore:

10 available officers does NOT automatically mean 10 deployable vehicles.

Example:

10 officers

6 qualified drivers

4 non-drivers

The Inspector may need:

- single-crewed units
- double-crewed units

Example:

10 officers

5 double-crewed cars

=

5 deployable units.

This should be a major resource-management mechanic.

Every officer should have:

driver_qualified: true/false

A double-crewed vehicle consumes two officers but creates one deployable unit.

This should affect the briefing and live resource picture.


============================================================
13. OFFICER DATA MODEL
============================================================

Each officer should have a lightweight data structure.

Minimum fields:

- id
- name
- rank
- experience_level
- driver_qualified
- fatigue
- morale
- current_status
- current_location
- current_task
- skills

Skills should be simple.

Suggested skills:

- communication
- response
- investigation
- community
- driving
- experience

Do not create complicated RPG statistics.

Use small ranges.

Example:

PC Harris

Experience: High
Driver: Yes
Communication: High
Response: High
Community: Medium
Fatigue: 30
Morale: 85

PC Lewis

Experience: Low
Driver: Yes
Communication: Medium
Response: Medium
Community: Medium
Fatigue: 15
Morale: 90


============================================================
14. OFFICER FATIGUE
============================================================

Fatigue is an important MVP mechanic.

Fatigue increases over time.

Fatigue increases faster when:

- officers remain on incidents for long periods
- officers work continuously
- officers deal with demanding incidents

Fatigue decreases during:

- breaks
- meals
- downtime
- station time

Fatigue should affect:

- performance
- availability
- morale
- willingness/ability to continue long tasks

The Inspector should be able to recall officers for breaks.

BUT:

Calling officers in for breaks removes them from street availability.

This creates a strategic decision.

Do NOT model sleep or real physiology in detail.

Keep it as a game system.


============================================================
15. SHIFT LENGTH
============================================================

Typical shift:

10–12 hours.

MVP should support configurable shift length.

Default:

12 hours.

Example:

17:00–05:00

The player can choose between:

10-hour
12-hour

for testing if useful.

Time should be simulated faster than real time.

The player should be able to:

- pause
- play at 1x
- play at 2x
- play at 4x

The simulation clock continues when playing.


============================================================
16. SHIFT BRIEFING
============================================================

Every shift begins with a briefing screen.

The player sees:

STAFFING

- establishment
- available officers
- minimum staffing
- sickness
- leave
- training
- supervisors
- neighbourhood availability
- specialist availability

INTELLIGENCE

3–5 current intelligence items.

COMMUNITY ISSUES

2–4 issues.

EVENTS

1 planned event or none.

INFORMATION GAPS

1–3 unknowns.

The player must set:

- three operational priorities
- proactive tasks
- patrol locations
- reserve units
- neighbourhood tasking
- specialist requests

Then confirm the shift plan.


============================================================
17. PRIORITY SYSTEM
============================================================

The player selects up to three priorities.

Examples:

- Football event
- Northside burglary pattern
- East Estate ASB
- Town-centre disorder
- Community engagement
- Vehicle crime

Priorities influence end-of-shift evaluation.

Priorities do NOT guarantee success.

The player can abandon/change priorities during the shift.

This should create a distinction between:

PLANNED INTENTION

and

ACTUAL OPERATIONAL DEMAND.


============================================================
18. PATROL TASKING
============================================================

Before the shift the player can assign officers/units to:

- general patrol
- directed patrol
- community engagement
- proactive task
- reserve

Directed patrol requires a location.

Examples:

- Northside
- railway station
- town centre
- East Estate

Patrol presence should influence district variables.

Example:

Police visibility increases.

Some incident probabilities decrease.

However:

Those officers are unavailable for other incidents.

This is a fundamental gameplay mechanic.


============================================================
19. RESPONSE RESERVE
============================================================

The player should explicitly decide how many units remain available for immediate response.

Example:

10 officers available

6 deployable units

Player chooses:

Reserve = 2 units.

This means:

4 units can be proactively committed.

The player should be warned if reserve becomes dangerously low.

Do not force a fixed reserve number.

The correct decision should depend on circumstances.


============================================================
20. INCIDENT ENGINE
============================================================

Incidents must be generated from world state.

Do NOT simply generate completely random incidents.

Incident probability should depend on:

- district
- time
- day
- weather
- events
- current district state
- recent incidents
- police visibility
- community tension
- known problems

Example:

Friday 22:00

Town Centre

High nightlife activity

High crowd density

Football dispersal

=

increased probability of:

- fights
- disorder
- assault
- theft
- vulnerability incidents

The system should use weighted probability.


============================================================
21. MVP INCIDENT TYPES
============================================================

Implement these 12 incident types:

1. Domestic incident
2. Shoplifting
3. Vehicle crime
4. Burglary
5. Assault/fight
6. ASB
7. Street robbery
8. Missing person
9. Concern for welfare
10. Road collision
11. Parking/obstruction
12. Neighbour dispute

Also include:

13. Suspicious activity

if implementation effort is reasonable.

Otherwise defer suspicious activity until after core incident types work.


============================================================
22. INCIDENT STATES
============================================================

Every incident should use a state machine.

Minimum states:

CREATED
REPORTED
ASSESSED
QUEUED
ASSIGNED
TRAVELLING
ON_SCENE
DEVELOPING
RESOLVED
OUTCOME

Any incident may enter:

ESCALATED

before resolution.

Example:

Shoplifting

REPORTED
    ->
ASSIGNED
    ->
TRAVELLING
    ->
ON_SCENE
    ->
DEVELOPING
    ->
RESOLVED


============================================================
23. INCIDENT INFORMATION
============================================================

When an incident arrives, the player receives incomplete information.

Example:

STREET ROBBERY

Railway Station

Caller reports:

- male assaulted
- phone stolen
- two suspects
- suspects ran north
- weapons unknown

Player should see:

KNOWN

UNKNOWN

The player should NOT receive perfect information.

This is important.

The player must make decisions under uncertainty.


============================================================
24. INCIDENT PRIORITY
============================================================

Incidents should have a priority level.

Use:

1 = critical
2 = urgent
3 = important
4 = routine
5 = non-urgent

Priority should be generated from:

- threat
- harm
- vulnerability
- immediacy
- opportunity

Do not attempt to replicate a specific police force's real incident grading system.

This is a gameplay abstraction.


============================================================
25. INCIDENT RESPONSE INTERFACE
============================================================

When an incident is selected, display:

- incident type
- location
- time reported
- priority
- threat
- harm
- vulnerability
- known information
- unknown information
- nearest resources
- resource ETA
- current commitments

Player actions:

SEND
SEND MULTIPLE
REQUEST INFORMATION
REQUEST SPECIALIST
HOLD / MONITOR
REASSIGN RESOURCE
SET COMMAND INTENT


============================================================
26. COMMAND INTENT
============================================================

For MVP, allow simple intent options:

RESPOND

CONTAIN

LOCATE

REASSURE

GATHER INTELLIGENCE

RESOLVE

The intent influences simplified officer behaviour and incident outcomes.

Do not build a complex tactical AI.

Example:

ASB + REASSURE

may increase:

community confidence

and reduce:

tension.

ASB + ENFORCEMENT/RESOLVE

may produce:

higher immediate resolution

but potentially greater community tension.

Keep effects simple and transparent.


============================================================
27. RESOURCE ASSIGNMENT
============================================================

The player can select individual units.

Each available unit should show:

- unit ID
- officer(s)
- location
- status
- ETA
- fatigue
- key skills

When selecting a busy unit, the game should show consequences.

Example:

UNIT 3

Currently:

Directed patrol — East Estate

Reassigning will:

- terminate current patrol
- reduce East Estate police visibility
- increase response capability elsewhere

This should be visible before confirmation.


============================================================
28. TRAVEL TIME
============================================================

Police units must physically move across the map.

Travel time depends on:

- distance
- road network
- traffic
- event congestion

For MVP, a simplified travel model is acceptable.

Do NOT implement realistic vehicle physics.

Police vehicles should visually travel along roads.

Pathfinding should use a navigation system rather than teleporting units.


============================================================
29. INCIDENT ESCALATION
============================================================

Incidents may worsen if:

- no resource is assigned
- resource response is delayed
- wrong resource is assigned
- incident conditions change

Example:

Domestic incident:

Verbal dispute
    ->
Threats
    ->
Physical violence
    ->
Injury

The player should receive notifications when an incident materially changes.


============================================================
30. INCIDENT OUTCOMES
============================================================

Incidents should resolve into different outcomes.

Example:

SHOPLIFTING

Possible:

- offender detained
- offender leaves
- evidence gathered
- victim satisfied
- insufficient evidence
- repeat offender identified

ASB:

- group dispersed
- warning given
- arrest
- group relocates
- unresolved

BURGLARY:

- suspect identified
- evidence gathered
- no suspect
- immediate response completed
- intelligence created

Do not make every outcome equally likely.

Officer capability, location, timing and player decisions should influence outcomes.


============================================================
31. SECONDARY INCIDENTS
============================================================

Incidents may create secondary demand.

Example:

Football match
    ->
crowd dispersal
    ->
traffic congestion
    ->
fighting
    ->
police resources committed
    ->
reduced town-centre coverage
    ->
shoplifting opportunity

This system does NOT need to be fully emergent in the MVP.

Use controlled chains for initial implementation.

The architecture should support more complex chains later.


============================================================
32. PLANNED EVENTS
============================================================

The MVP should contain at least one planned event:

WESTFORD UNITED FOOTBALL MATCH

Example:

Kick-off: 19:30

Attendance: 4,500

Dispersal: approximately 21:15–22:00

Risk: Moderate

Effects:

- increased traffic
- increased crowd density
- increased town-centre demand
- increased likelihood of disorder
- increased police resource demand

The player must decide how to resource the event.

The event should modify the simulation rather than simply creating a single incident.


============================================================
33. DAY/NIGHT CYCLE
============================================================

The map must visually change with time.

Morning
Afternoon
Evening
Night

Include:

- changing lighting
- streetlights
- changing traffic/pedestrian density

The simulation should also alter incident probabilities based on time.

Example:

Night-time economy activity increases during evening/night.

This should be a visual AND gameplay system.


============================================================
34. WEATHER
============================================================

MVP may include:

- clear
- rain

Weather can influence:

- traffic
- pedestrian activity
- road incidents
- outdoor ASB

Do not build detailed weather simulation.


============================================================
35. LIVE MAP
============================================================

The main game screen is a full-town map.

The map must remain visible during normal gameplay.

It should feel like a living SimCity-style town.

Visual elements:

- roads
- buildings
- parks
- traffic
- pedestrians
- police station
- police vehicles
- incidents
- key landmarks

The player should be able to zoom.

Recommended levels:

CITY VIEW
DISTRICT VIEW
STREET VIEW

Do not implement true 3D in MVP.


============================================================
36. POLICE VEHICLES ON MAP
============================================================

Police vehicles should visibly move.

Each unit should have:

- map position
- destination
- route
- status
- current task

Statuses:

AVAILABLE
PATROL
TRAVELLING
ON_SCENE
BREAK
UNAVAILABLE

Use clear visual icons.


============================================================
37. INCIDENT MARKERS
============================================================

Use map markers.

Colour/state:

Green = routine
Yellow = important
Orange = urgent
Red = critical

When zoomed out, nearby incidents can cluster.

When zoomed in, individual incidents become visible.

Do not clutter the map.


============================================================
38. TOP UI
============================================================

Main screen should display:

Current time

Shift time

Available units

Active incidents

Minimum staffing status

Fatigue warnings

Resource pressure

Example:

21:47

SHIFT 17:00–05:00

5 AVAILABLE

3 ACTIVE

10/10 MINIMUM

2 FATIGUE WARNINGS


============================================================
39. EVENT FEED
============================================================

A scrolling event feed should show:

- new incidents
- incident escalation
- resource changes
- specialist availability
- completed tasks
- intelligence updates
- important officer updates

Critical incidents should generate larger notifications.


============================================================
40. PAUSE / SPEED
============================================================

Include:

PAUSE
1x
2x
4x

Pause must completely stop simulation progression.

The player should be able to pause at any time.

This is particularly important for mobile gameplay.


============================================================
41. MAP OVERLAYS
============================================================

MVP overlays:

- ASB
- violence
- burglary
- police visibility
- demand

Overlays should be simple heatmaps.

Some information should be incomplete.

Low intelligence quality should produce less accurate overlays.


============================================================
42. COMMUNITY SYSTEM
============================================================

Each district has:

community confidence
community tension

Police activity affects these values.

Positive engagement:

confidence increases.

Heavy-handed or ineffective response:

tension may increase.

Ignoring persistent issues:

confidence may decrease.

Keep the model simple.

The objective is to create consequences, not a sociology simulator.


============================================================
43. INTELLIGENCE SYSTEM
============================================================

The player should receive intelligence from:

- incident outcomes
- neighbourhood engagement
- community reports
- repeated incidents
- proactive tasks

Intelligence can:

- reveal hotspots
- identify patterns
- reveal information gaps
- improve district understanding

The player should not have perfect information.


============================================================
44. FATIGUE / BREAK SYSTEM
============================================================

Officers accumulate fatigue.

The player receives warnings.

Example:

"PC Harris has reached elevated fatigue."

The player can:

SEND FOR BREAK

But doing so reduces available resources.

Breaks should last a simplified period.

Do not simulate detailed meal policy.


============================================================
45. END OF SHIFT
============================================================

When the shift ends, display:

SHIFT DEBRIEF

Include:

RESPONSE
- average response performance
- unresolved incidents
- delayed incidents

PREVENTION
- proactive tasks
- district changes

INTELLIGENCE
- intelligence gathered
- information gaps resolved

COMMUNITY
- confidence changes
- tension changes

WORKFORCE
- fatigue
- breaks
- sickness risk
- morale

OPERATIONAL PRIORITIES
- priority achieved / partially achieved / missed

The game should provide a short narrative summary.

Example:

"Your decision to retain two response units allowed Westford to absorb the football dispersal period without significant response delays. However, Northside burglary demand increased after proactive patrols were withdrawn."

This is more important than a single numerical score.


============================================================
46. COMMAND PROFILE
============================================================

MVP should NOT implement a full career progression system.

However, the debrief should calculate broad performance dimensions:

Response
Prevention
Intelligence
Community
Workforce

These can be shown as:

Poor
Developing
Good
Strong
Excellent

This system will later feed into career progression.


============================================================
47. PERSISTENT WORLD
============================================================

MVP should persist the town state between shifts locally.

At minimum:

- district crime variables
- community confidence
- community tension
- police visibility
- unresolved problems

The next shift should begin with the consequences of the previous shift.

Example:

Shift 1:

Northside burglary = Medium

Player ignores it.

Shift 2:

Northside burglary = High.

This is essential.

The town must remember.


============================================================
48. RANDOMNESS
============================================================

Use controlled randomness.

Do not create purely random outcomes.

The outcome of an event should be influenced by:

- district conditions
- incident severity
- resource quality
- response time
- officer capability
- current fatigue
- player decisions
- recent events

Randomness should introduce uncertainty rather than chaos.


============================================================
49. DESIGN PRINCIPLE — PLAYER AGENCY
============================================================

The player must always feel:

"I caused this."

Avoid outcomes that feel completely random.

If the player makes a poor decision, the game should create a believable consequence.

If the player makes a strong decision, the game should create a believable benefit.


============================================================
50. DESIGN PRINCIPLE — NO PERFECT INFORMATION
============================================================

The player should never see the underlying simulation values directly unless appropriate.

The player should infer the state of Westford through:

- reports
- incidents
- intelligence
- map overlays
- community feedback
- officer updates

This creates uncertainty and strategic thinking.


============================================================
51. DESIGN PRINCIPLE — RESOURCE SCARCITY
============================================================

There should usually be more demand than ideal resources.

The player should regularly have to decide:

"Which problem gets my resources?"

This is the central strategy mechanic.


============================================================
52. DESIGN PRINCIPLE — CONSEQUENCES
============================================================

Every major decision should have potential consequences.

Examples:

Pull unit from ASB patrol
    ->
lower police visibility
    ->
higher ASB probability

Keep unit at football event
    ->
better event coverage
    ->
less response capacity elsewhere

Send officers for a break
    ->
better officer welfare
    ->
fewer available units

Use neighbourhood officers for response
    ->
better immediate response
    ->
less community engagement


============================================================
53. MVP MAP REQUIREMENTS
============================================================

Build one complete fictional town.

It should include:

6 districts

Approximately:

500–800 visual buildings

50–100 meaningful gameplay locations

Road network suitable for police vehicle pathfinding.

Buildings do NOT need interiors.

Citizens do NOT need individual simulation.

Traffic and pedestrians can use simplified visual simulation.


============================================================
54. MVP VISUAL QUALITY
============================================================

Prioritise:

- attractive
- clean
- readable
- recognisable
- mobile-friendly

Do NOT spend excessive development time creating photorealistic graphics.

A stylised isometric/angled 2D town is preferred.

The player must be able to understand:

Where am I?
Where are my officers?
Where are the incidents?
Where is demand increasing?
Where are my resources?

within a few seconds.


============================================================
55. AUDIO
============================================================

MVP audio should be minimal.

Optional:

- subtle ambient town noise
- notification sound
- incident alert
- vehicle sound

Do not build voice acting.

Do not build radio dialogue.


============================================================
56. MOBILE UI
============================================================

Touch-first design.

Buttons must be large enough for mobile use.

Avoid tiny controls.

Information should appear through:

- panels
- cards
- overlays
- bottom sheets

The map should remain the dominant visual.


============================================================
57. GAME STATE
============================================================

The game should have a central GameState.

Suggested conceptual structure:

GameState
    |
    +-- current_time
    +-- shift_start
    +-- shift_end
    +-- districts
    +-- officers
    +-- units
    +-- incidents
    +-- events
    +-- intelligence
    +-- community_state
    +-- weather
    +-- traffic
    +-- player_priorities


============================================================
58. SIMULATION TICK
============================================================

Use a controlled simulation tick.

For example:

simulation updates multiple times per real second.

But do NOT make every object update every frame unnecessarily.

Separate:

VISUAL FRAME RATE

from

SIMULATION UPDATE RATE.

This is important for performance.


============================================================
59. DATA-DRIVEN DESIGN
============================================================

Whenever practical, use data/configuration rather than hard-coded values.

For example:

district definitions
incident definitions
officer definitions
event definitions
building definitions

should be easy to modify.

Use resources/data files or equivalent Godot structures.

The goal is for new incident types to be added without rewriting the entire simulation.


============================================================
60. RECOMMENDED PROJECT STRUCTURE
============================================================

Suggested structure:

res://

    scenes/
        main/
        map/
        ui/
        units/
        incidents/

    scripts/
        simulation/
            game_state.gd
            game_clock.gd
            shift_manager.gd
            district_manager.gd
            incident_manager.gd
            officer_manager.gd
            resource_manager.gd
            event_manager.gd
            intelligence_manager.gd
            fatigue_manager.gd
            community_manager.gd

        world/
            world_manager.gd
            navigation_manager.gd

        units/
            police_unit.gd
            officer.gd

        incidents/
            incident.gd
            incident_definition.gd
            incident_generator.gd
            incident_state_machine.gd

        ui/
            briefing_ui.gd
            incident_panel.gd
            event_feed.gd
            debrief_ui.gd
            map_overlay_ui.gd

    data/
        districts/
        incidents/
        officers/
        events/

    assets/
        map/
        vehicles/
        buildings/
        UI/

    tests/


============================================================
61. DEVELOPMENT ORDER
============================================================

Do NOT attempt to build everything simultaneously.

Build in the following phases.

PHASE 1 — SIMULATION PROTOTYPE

Build without beautiful graphics.

Implement:

- GameClock
- ShiftManager
- Districts
- Officers
- Units
- basic incidents
- resource availability
- incident assignment
- simulation progression

Goal:

A text/debug version of a shift should work.

PHASE 2 — INCIDENT LOOP

Implement:

- incident generation
- incident priority
- assignment
- travel
- escalation
- resolution
- outcomes

Goal:

A player can manage incidents during a shift.

PHASE 3 — BASIC MAP

Implement:

- town map
- roads
- districts
- police station
- key locations
- moving police units
- incident markers

Goal:

The simulation can now be watched visually.

PHASE 4 — BRIEFING

Implement:

- staffing screen
- intelligence
- priorities
- patrol tasking
- reserve
- events

Goal:

Player plans the shift before starting.

PHASE 5 — LIVE UI

Implement:

- incident panel
- event feed
- resource bar
- clock
- pause
- speed controls
- overlays

PHASE 6 — FATIGUE + COMMUNITY + INTELLIGENCE

Implement simplified versions.

PHASE 7 — END SHIFT

Implement:

- debrief
- performance dimensions
- town state persistence

PHASE 8 — POLISH

Improve:

- animations
- map appearance
- transitions
- sounds
- UI
- mobile usability


============================================================
62. MOST IMPORTANT PROTOTYPE
============================================================

Before creating the complete town, create a SMALL playable test map.

Use:

3 districts

10–15 buildings

5 roads

5 police units

approximately 5 incident types

1 planned event

1 shift

This prototype should answer:

"Is the command gameplay fun?"

If not, improve gameplay before expanding the map.


============================================================
63. ACCEPTANCE TEST — CORE GAMEPLAY
============================================================

The MVP is successful if a player can:

1. Start a shift.
2. See realistic staffing limitations.
3. Review a briefing.
4. Set priorities.
5. Position units.
6. Start the simulation.
7. See police units moving.
8. Receive incidents.
9. Assess an incident.
10. See available resources.
11. Assign a unit.
12. Watch it travel.
13. Watch the incident develop.
14. Deal with escalation.
15. Receive another incident while the first is active.
16. Reallocate resources.
17. Manage fatigue.
18. See district conditions change.
19. Finish the shift.
20. Receive a meaningful debrief.
21. Start another shift where previous decisions matter.

If these 21 things work, the MVP has achieved its primary objective.


============================================================
64. PERFORMANCE REQUIREMENT
============================================================

The game should remain responsive on a modern mobile device.

Do not simulate hundreds of individual AI citizens.

Use aggregate simulation where possible.

Do not create unnecessary per-frame calculations.

The simulation should be deterministic where useful for debugging, with a controllable random seed.


============================================================
65. DEBUGGING TOOLS
============================================================

Create a developer/debug mode.

It should allow:

- pause
- change simulation speed
- spawn incident
- complete incident
- force escalation
- change district values
- make officer unavailable
- restore officer
- trigger event
- advance time
- inspect GameState

This is extremely important for development.

Do not remove debug tools during MVP.


============================================================
66. TESTING
============================================================

Create basic automated tests for:

- incident generation
- incident state transitions
- officer availability
- vehicle crew formation
- travel time
- fatigue
- resource reassignment
- district state changes
- shift completion

Also manually test:

- multiple simultaneous incidents
- minimum staffing
- all units committed
- specialist unavailable
- officer fatigue
- incident escalation
- event demand spike


============================================================
67. SAVE SYSTEM
============================================================

MVP only needs local save.

Save:

- current shift
- district states
- player priorities
- resource states
- completed incidents
- town state

No online accounts.

No cloud save.


============================================================
68. FUTURE FEATURES — DO NOT IMPLEMENT
============================================================

Architecture may allow:

CAREER

- promotions
- transfers
- multiple commands
- larger cities
- different command roles

PERSONNEL

- richer officer personalities
- development
- training
- sickness
- leave management

POLICING

- crime investigation
- custody
- detectives
- firearms
- public order
- roads policing
- specialist operations

WORLD

- multiple towns
- cities
- persistent national map
- changing politics
- economic conditions
- major events

SOCIAL

- leaderboards
- friends
- multiplayer
- scenarios

Do not implement these in MVP.


============================================================
69. FUTURE CAREER STRUCTURE
============================================================

Potential future progression:

Inspector
    ->
larger town
    ->
small city
    ->
inner city
    ->
major city
    ->
capital

The player's role should change with scale.

At small-town level:

Individual units can be managed.

At city level:

Teams and supervisors become the primary resources.

At major-city level:

Multiple command areas are managed.

Do not implement this yet.


============================================================
70. DESIGN WARNING
============================================================

Do NOT allow scope creep.

If a proposed feature does not directly improve the core loop:

BRIEF
PLAN
DEPLOY
RESPOND
REASSESS
MANAGE
DEBRIEF

defer it.

The first objective is not to make a huge game.

The first objective is to prove that the simulation is fun.


============================================================
71. CLAUDE CODE WORKING RULES
============================================================

Before writing substantial code:

1. Analyse this specification.
2. Inspect the existing repository.
3. Identify missing architecture.
4. Propose a development plan.
5. Identify technical risks.
6. Identify any ambiguities.
7. Ask questions only where a decision genuinely affects architecture or gameplay.
8. Do not invent major features.
9. Do not silently expand the scope.

Build incrementally.

After each major phase:

- run the project
- test the relevant systems
- fix errors
- explain what was implemented
- identify remaining issues

Do not move to the next phase if the previous phase is fundamentally broken.


============================================================
72. CLAUDE CODE — CODE QUALITY
============================================================

Prioritise:

- readable code
- modular systems
- reusable components
- data-driven definitions
- clear naming
- comments only where useful
- minimal coupling
- testability

Avoid:

- giant monolithic scripts
- hard-coded incident logic everywhere
- hard-coded officer logic everywhere
- UI controlling simulation state directly
- duplicated systems
- unnecessary third-party dependencies


============================================================
73. CLAUDE CODE — DESIGN DECISION RULE
============================================================

If something is not specified:

Prefer the simplest implementation that:

1. preserves the intended gameplay,
2. keeps the architecture extensible,
3. does not introduce unnecessary complexity.

Do NOT invent a major gameplay system without asking.

Minor implementation decisions can be made independently.


============================================================
74. MVP SUCCESS CRITERIA
============================================================

The MVP is successful when:

A player can sit down and play a complete 10–12 hour simulated shift in Westford.

During the shift:

- demand changes
- incidents arrive
- officers move around the town
- resources become scarce
- incidents compete for resources
- incidents can escalate
- proactive policing has consequences
- fatigue matters
- events affect demand
- districts change
- the player makes meaningful decisions

At the end:

The player receives a debrief explaining:

WHAT HAPPENED

WHY IT HAPPENED

HOW THEIR DECISIONS CONTRIBUTED

WHAT THEY DID WELL

WHAT THEY MISSED

WHAT HAS CHANGED IN WESTFORD

The player should then want to press:

START NEXT SHIFT


============================================================
75. FINAL DEVELOPMENT PRINCIPLE
============================================================

The game should create stories.

A good shift should be remembered because of what happened.

Example:

"I sent Harris to East Estate because of the ASB reports. That meant he wasn't available when the robbery came in. I pulled Patel off the football operation to cover it, which weakened the stadium response. The football dispersal then caused disorder in the town centre. By midnight I had almost no reserve. I should have positioned resources differently."

That is the experience we are trying to create.

The game is NOT:

"Click the correct answer."

The game IS:

"Make the best decision you can with incomplete information and limited resources, then deal with what happens next."

============================================================
END OF WESTFORD MVP SPECIFICATION v0.1
============================================================
