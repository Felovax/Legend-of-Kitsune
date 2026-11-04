class_name Rng32
extends RefCounted
## Deterministic PRNG (xoshiro128**) using only 32-bit-safe integer math, so a
## seed produces the same sequence on every device and can be replayed on a
## server. Never use Godot's global randi()/randf() inside game logic.

const MASK32 := 0xFFFFFFFF

var _s0: int = 0
var _s1: int = 0
var _s2: int = 0
var _s3: int = 0


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	var x := (seed_value ^ (seed_value >> 32)) & MASK32
	var state: Array[int] = []
	for i in 4:
		x = (x + 0x9E3779B9) & MASK32
		state.append(fmix32(x))
	_s0 = state[0]
	_s1 = state[1]
	_s2 = state[2]
	_s3 = state[3]
	if _s0 == 0 and _s1 == 0 and _s2 == 0 and _s3 == 0:
		_s0 = 1


## Returns an unsigned 32-bit integer.
func next_u32() -> int:
	var result := mul32(rotl(mul32(_s1, 5), 7), 9)
	var t := (_s1 << 9) & MASK32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = rotl(_s3, 11)
	return result


## Uniform integer in [0, n). n must be in 1..2^31.
func next_below(n: int) -> int:
	assert(n > 0 and n <= 0x80000000, "next_below: n out of range")
	return (next_u32() * n) >> 32


## Integer in [low, high] inclusive.
func range_int(low: int, high: int) -> int:
	return low + next_below(high - low + 1)


## True with probability chance_bp / 10000.
func chance_bp(chance: int) -> bool:
	if chance <= 0:
		return false
	if chance >= 10000:
		return true
	return next_below(10000) < chance


## Derives an independent seed for a named stream (e.g. combat, loot, draft),
## so adding draws in one stream never changes another.
static func derive_seed(base_seed: int, stream: int) -> int:
	var x := (base_seed ^ (base_seed >> 32)) & MASK32
	x = fmix32((x ^ mul32(stream & MASK32, 0x9E3779B9)) & MASK32)
	return fmix32((x + stream) & MASK32)


static func fmix32(value: int) -> int:
	var z := value & MASK32
	z = mul32(z ^ (z >> 16), 0x85EBCA6B)
	z = mul32(z ^ (z >> 13), 0xC2B2AE35)
	return (z ^ (z >> 16)) & MASK32


## (a * b) mod 2^32 without overflowing signed 64-bit integers.
static func mul32(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var low := a * (b & 0xFFFF)
	var high := ((a * (b >> 16)) & 0xFFFF) << 16
	return (low + high) & MASK32


static func rotl(x: int, k: int) -> int:
	x &= MASK32
	return ((x << k) | (x >> (32 - k))) & MASK32
