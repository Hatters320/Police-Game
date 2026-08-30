class_name SeasonCycle
extends RefCounted
## Which season the town is in, and what that means for daylight.
##
## Stateless and derived from the shift number, exactly like DutyPattern --
## no new persistence, and a save that only stores the next shift number
## still lands the player back in the right season. Seasons advance every
## SHIFTS_PER_SEASON shifts, so a full year is 4 x that.

const SHIFTS_PER_SEASON := 8

static func season_for_shift(shift_number: int) -> GameEnums.Season:
	var index: int = ((shift_number - 1) / SHIFTS_PER_SEASON) % 4
	return index as GameEnums.Season

static func label(season: GameEnums.Season) -> String:
	match season:
		GameEnums.Season.SPRING: return "Spring"
		GameEnums.Season.SUMMER: return "Summer"
		GameEnums.Season.AUTUMN: return "Autumn"
		GameEnums.Season.WINTER: return "Winter"
	return "Spring"

## Sunrise and sunset, in minutes past midnight, for a British town --
## which is the whole point of the seasonal system being visible rather
## than cosmetic. A 07:00-19:00 day shift starts and ends in daylight in
## June and starts *and* ends in the dark in December, without the shift
## times themselves changing at all.
static func sunrise_minute(season: GameEnums.Season) -> int:
	match season:
		GameEnums.Season.SPRING: return 6 * 60 + 30
		GameEnums.Season.SUMMER: return 5 * 60
		GameEnums.Season.AUTUMN: return 7 * 60
		GameEnums.Season.WINTER: return 8 * 60
	return 7 * 60

static func sunset_minute(season: GameEnums.Season) -> int:
	match season:
		GameEnums.Season.SPRING: return 19 * 60 + 30
		GameEnums.Season.SUMMER: return 21 * 60 + 30
		GameEnums.Season.AUTUMN: return 18 * 60 + 30
		GameEnums.Season.WINTER: return 16 * 60 + 30
	return 19 * 60

## How long dawn and dusk take to run their course. Longer in summer (a
## drawn-out northern evening), shortest in winter.
static func twilight_minutes(season: GameEnums.Season) -> int:
	match season:
		GameEnums.Season.SUMMER: return 75
		GameEnums.Season.WINTER: return 45
	return 60

static func daylight_hours(season: GameEnums.Season) -> float:
	return float(sunset_minute(season) - sunrise_minute(season)) / 60.0
