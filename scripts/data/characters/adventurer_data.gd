class_name AdventurerData
extends Resource

enum Role {
	FRONTLINER,
	SCOUT,
	CASTER,
	HEALER,
}

@export var display_name: String = ""
@export var class_title: String = ""
@export var subclass_title: String = ""
@export var role: Role = Role.FRONTLINER
@export_range(0, 20) var attack: int = 5
@export_range(0, 20) var defence: int = 5
@export_range(0, 20) var speed: int = 5
