class_name JoinCode
extends RefCounted

# Turns the host's local network address into a code such as K7F2-QX9M, and back.
# The code holds the 32-bit address plus 8 check bits, so a mistyped or swapped
# character is rejected instead of connecting somewhere else. It uses Crockford's
# base 32, which leaves out I, L, O and U so the code is hard to misread.

const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LENGTH: int = 8


# Returns "" if the address isn't an IPv4 address.
static func encode(address: String) -> String:
	var parts: PackedStringArray = address.split(".")

	if parts.size() != 4:
		return ""

	var value: int = 0

	for part: String in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""

		value = (value << 8) | int(part)

	var bits: int = (value << 8) | _get_check(value)
	var code: String = ""

	for _character: int in LENGTH:
		code = ALPHABET[bits & 31] + code
		bits >>= 5

	return "%s-%s" % [code.left(4), code.right(4)]


# Returns the address, or "" if the code isn't valid. Ignores case, spaces and
# dashes, and reads O as 0 and I or L as 1.
static func decode(code: String) -> String:
	var clean: String = code.to_upper().replace("-", "").replace(" ", "")
	clean = clean.replace("O", "0").replace("I", "1").replace("L", "1")

	if clean.length() != LENGTH:
		return ""

	var bits: int = 0

	for character: String in clean:
		var digit: int = ALPHABET.find(character)

		if digit < 0:
			return ""

		bits = (bits << 5) | digit

	var value: int = bits >> 8

	if bits & 255 != _get_check(value):
		return ""

	return "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]


# True for an address other people can reach over the internet, rather than one
# that only exists inside a home network or an internet provider's shared network.
static func is_public(address: String) -> bool:
	if _rank(address) != 2:
		return false

	var parts: PackedStringArray = address.split(".")
	var first: int = int(parts[0])
	var second: int = int(parts[1])
	return first != 0 and not (first == 100 and second >= 64 and second <= 127)


# Picks the address a partner on the same network is most likely to reach.
static func pick_local_address(addresses: PackedStringArray) -> String:
	var best: String = ""
	var best_rank: int = 0

	for address: String in addresses:
		var rank: int = _rank(address)

		if rank > best_rank:
			best = address
			best_rank = rank

	return best


# Home networks first. Link-local addresses come last, for computers wired
# straight together without a router.
static func _rank(address: String) -> int:
	if encode(address).is_empty() or address.begins_with("127."):
		return 0

	if address.begins_with("192.168."):
		return 5

	if address.begins_with("10."):
		return 4

	var second: int = int(address.get_slice(".", 1))

	if address.begins_with("172.") and second >= 16 and second <= 31:
		return 3

	return 1 if address.begins_with("169.254.") else 2


static func _get_check(value: int) -> int:
	var check: int = 0x5A

	for shift: int in [24, 16, 8, 0]:
		check = (check * 31 + ((value >> shift) & 255)) & 255

	return check
