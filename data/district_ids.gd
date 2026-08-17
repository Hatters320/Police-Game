class_name DistrictIds
extends RefCounted
## Canonical district id strings, shared by every map factory (small test
## map and the full Westford map) and by anything that references a
## district without caring which map built it (e.g. EventFactory's
## football match, which always affects "town_centre" regardless of
## which WorldMapData is currently loaded).

const TOWN_CENTRE := "town_centre"
const NORTHSIDE := "northside"
const EAST_ESTATE := "east_estate"
const SOUTH_RESIDENTIAL := "south_residential"
const WEST_INDUSTRIAL := "west_industrial"
const RURAL_OUTSKIRTS := "rural_outskirts"
