extends TestCase
## Known-answer values come from an independent Python reference implementation
## of the same algorithm, so any platform or refactor drift is caught.


func test_known_sequence() -> void:
	var r := Rng32.new(12345)
	var got: Array[int] = []
	for i in 5:
		got.append(r.next_u32())
	assert_eq(got, [518667457, 440444462, 4232892992, 3757857622, 3939018813] as Array[int])


func test_negative_seed_known_sequence() -> void:
	var r := Rng32.new(-987654321987)
	assert_eq(r.next_u32(), 9675196)
	assert_eq(r.next_u32(), 2826313874)
	assert_eq(r.next_u32(), 2069138013)


func test_next_below_known_values() -> void:
	var r := Rng32.new(7)
	var got: Array[int] = []
	for i in 8:
		got.append(r.next_below(100))
	assert_eq(got, [23, 51, 44, 17, 56, 47, 51, 35] as Array[int])


func test_derive_seed_known_values() -> void:
	assert_eq(Rng32.derive_seed(12345, 1), 2265714769)
	assert_eq(Rng32.derive_seed(12345, 2), 3916424534)
	assert_eq(Rng32.derive_seed((1 << 40) + 3, 7), 1363723710)


func test_outputs_stay_in_32_bits() -> void:
	var r := Rng32.new(99)
	var ok := true
	for i in 10000:
		var v := r.next_u32()
		if v < 0 or v > Rng32.MASK32:
			ok = false
	assert_true(ok)


func test_next_below_is_roughly_uniform() -> void:
	var r := Rng32.new(2024)
	var buckets := [0, 0, 0, 0]
	for i in 40000:
		buckets[r.next_below(4)] += 1
	for count: int in buckets:
		assert_between(count, 9500, 10500)


func test_chance_bp_edges_and_rate() -> void:
	var r := Rng32.new(5)
	assert_false(r.chance_bp(0))
	assert_true(r.chance_bp(10000))
	var hits := 0
	for i in 20000:
		if r.chance_bp(2500):
			hits += 1
	assert_between(hits, 4700, 5300)


func test_mul32_matches_wrapping_multiplication() -> void:
	assert_eq(Rng32.mul32(0xFFFFFFFF, 0xFFFFFFFF), 1)
	assert_eq(Rng32.mul32(0x9E3779B9, 3), (0x9E3779B9 * 3) & Rng32.MASK32)
