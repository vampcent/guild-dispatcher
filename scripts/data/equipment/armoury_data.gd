class_name ArmouryData
extends Resource

# What the market sells.
@export var weapons: Array[WeaponData] = []
@export var armour: Array[ArmourData] = []
@export var items: Array[ItemData] = []
# What a new guild's armoury holds, one entry per copy.
@export var starting_stock: Array[Resource] = []
