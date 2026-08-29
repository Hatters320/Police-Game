class_name DutyPattern
extends RefCounted
## The station's rotating duty roster: two day shifts, then two night
## shifts, repeating (spec section 15 -- "rotating shift pattern"). Turns a
## shift number into everything that differs between the two halves of the
## cycle: when the shift starts, how tired the crew comes on, and how many
## of them there are.
##
## Stateless -- every method is pure given a shift number, matching
## IncidentProbabilityEngine/DispatchScorer's engine-class shape. Not wired
## into SimulationCore; main.gd calls it once when building each shift.

const DAY_START_MINUTE := 7 * 60 # 07:00
const NIGHT_START_MINUTE := 19 * 60 # 19:00

## Both halves of the cycle are 12-hour shifts, so this is shared.
const DURATION_MINUTES := 12 * 60

## Shift numbers are 1-based, so shift 1 and 2 are days, 3 and 4 nights,
## 5 and 6 days again.
static func is_night_shift(shift_number: int) -> bool:
	return ((shift_number - 1) / 2) % 2 == 1

## True on the second shift of a day/day or night/night pair -- the one
## the crew comes on to already carrying the previous shift's tiredness.
static func is_second_of_pair(shift_number: int) -> bool:
	return (shift_number - 1) % 2 == 1

static func start_minute(shift_number: int) -> int:
	return NIGHT_START_MINUTE if is_night_shift(shift_number) else DAY_START_MINUTE

static func label(shift_number: int) -> String:
	return "Night" if is_night_shift(shift_number) else "Day"

## Fatigue every officer starts this shift on.
##
## Scope note, stated plainly: OfficerFactory builds brand-new Officer
## instances every shift, so fatigue genuinely does not persist between
## shifts today -- real carry-over would need per-officer save/load, well
## beyond this system. This models the *shape* the duty cycle is known to
## produce instead: nights cost more sleep than days, and the second of a
## pair lands on a crew that has not fully recovered from the first. It's
## a deliberate proxy, not simulated history.
const FATIGUE_DAY_FIRST := 0.0
const FATIGUE_DAY_SECOND := 10.0
const FATIGUE_NIGHT_FIRST := 8.0
const FATIGUE_NIGHT_SECOND := 20.0

static func starting_fatigue(shift_number: int) -> float:
	if is_night_shift(shift_number):
		return FATIGUE_NIGHT_SECOND if is_second_of_pair(shift_number) else FATIGUE_NIGHT_FIRST
	return FATIGUE_DAY_SECOND if is_second_of_pair(shift_number) else FATIGUE_DAY_FIRST

## Officers dropped from the roster on nights. The full roster is 12; this
## lands the night crew on OfficerFactory.MINIMUM_STAFFING exactly, so a
## night shift is thinner without dipping below the establishment's own
## stated floor.
const NIGHT_STAFFING_CUT := 2

static func staffing_cut(shift_number: int) -> int:
	return NIGHT_STAFFING_CUT if is_night_shift(shift_number) else 0
