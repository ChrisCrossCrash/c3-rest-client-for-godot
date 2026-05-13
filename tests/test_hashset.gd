extends GutTest


class TestInit:
    extends GutTest

    func test_empty_init() -> void:
        var s := C3Utils.HashSet.new()
        assert_eq(s.size(), 0)
        assert_true(s.is_empty())

    func test_init_from_array() -> void:
        var s := C3Utils.HashSet.new([1, 2, 3])
        assert_eq(s.size(), 3)
        assert_true(s.has(1))
        assert_true(s.has(2))
        assert_true(s.has(3))

    func test_init_deduplicates() -> void:
        var s := C3Utils.HashSet.new([1, 1, 2, 2, 3])
        assert_eq(s.size(), 3)

    func test_init_from_dictionary() -> void:
        var s := C3Utils.HashSet.new({"a": 1, "b": 2})
        assert_eq(s.size(), 2)
        assert_true(s.has("a"))
        assert_true(s.has("b"))

    func test_init_from_hashset() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := C3Utils.HashSet.new(a)
        assert_eq(b.size(), 3)
        assert_true(b.has(1))


class TestCoreMutation:
    extends GutTest

    func test_add() -> void:
        var s := C3Utils.HashSet.new()
        s.add(42)
        assert_true(s.has(42))
        assert_eq(s.size(), 1)

    func test_add_duplicate_no_growth() -> void:
        var s := C3Utils.HashSet.new()
        s.add(1)
        s.add(1)
        assert_eq(s.size(), 1)

    func test_remove() -> void:
        var s := C3Utils.HashSet.new([1, 2, 3])
        s.remove(2)
        assert_false(s.has(2))
        assert_eq(s.size(), 2)

    func test_remove_missing_leaves_set_unchanged() -> void:
        var s := C3Utils.HashSet.new([1, 2])
        s.remove(99)
        assert_eq(s.size(), 2)
        assert_push_error_count(1)

    func test_discard_present() -> void:
        var s := C3Utils.HashSet.new([1, 2])
        s.discard(1)
        assert_false(s.has(1))
        assert_eq(s.size(), 1)

    func test_discard_absent_is_silent() -> void:
        var s := C3Utils.HashSet.new([1])
        s.discard(99)
        assert_eq(s.size(), 1)

    func test_pop_returns_element() -> void:
        var s := C3Utils.HashSet.new([7])
        var v: Variant = s.pop()
        assert_eq(v, 7)
        assert_true(s.is_empty())

    func test_pop_empty_returns_null() -> void:
        var s := C3Utils.HashSet.new()
        assert_null(s.pop())
        assert_push_error_count(1)

    func test_clear() -> void:
        var s := C3Utils.HashSet.new([1, 2, 3])
        s.clear()
        assert_true(s.is_empty())
        assert_eq(s.size(), 0)


class TestQueries:
    extends GutTest

    func test_has_present() -> void:
        var s := C3Utils.HashSet.new(["x"])
        assert_true(s.has("x"))

    func test_has_absent() -> void:
        var s := C3Utils.HashSet.new(["x"])
        assert_false(s.has("y"))

    func test_copy_is_independent() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := a.copy()
        b.add(4)
        assert_false(a.has(4))
        assert_eq(a.size(), 3)

    func test_values_returns_all_elements() -> void:
        var s := C3Utils.HashSet.new([1, 2, 3])
        var vals := s.values()
        assert_eq(vals.size(), 3)
        assert_true(vals.has(1))
        assert_true(vals.has(2))
        assert_true(vals.has(3))

    func test_to_string() -> void:
        var s := C3Utils.HashSet.new([1])
        assert_true(str(s).begins_with("HashSet("))


class TestSetAlgebra:
    extends GutTest

    func test_union() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([2, 3])
        var r := a.union(b)
        assert_eq(r.size(), 3)
        assert_true(r.has(1) and r.has(2) and r.has(3))

    func test_union_does_not_mutate_self() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([3])
        a.union(b)
        assert_eq(a.size(), 2)

    func test_union_with_array() -> void:
        var a := C3Utils.HashSet.new([1])
        var r := a.union([2, 3])
        assert_eq(r.size(), 3)

    func test_intersection() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := C3Utils.HashSet.new([2, 3, 4])
        var r := a.intersection(b)
        assert_eq(r.size(), 2)
        assert_true(r.has(2) and r.has(3))
        assert_false(r.has(1))

    func test_intersection_empty_result() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([3, 4])
        assert_true(a.intersection(b).is_empty())

    func test_difference() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := C3Utils.HashSet.new([2, 3])
        var r := a.difference(b)
        assert_eq(r.size(), 1)
        assert_true(r.has(1))

    func test_difference_no_overlap() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([3, 4])
        assert_eq(a.difference(b).size(), 2)

    func test_symmetric_difference() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := C3Utils.HashSet.new([2, 3, 4])
        var r := a.symmetric_difference(b)
        assert_eq(r.size(), 2)
        assert_true(r.has(1) and r.has(4))
        assert_false(r.has(2))

    func test_symmetric_difference_no_overlap() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([3, 4])
        assert_eq(a.symmetric_difference(b).size(), 4)

    func test_symmetric_difference_identical() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([1, 2])
        assert_true(a.symmetric_difference(b).is_empty())


class TestInPlaceAlgebra:
    extends GutTest

    func test_update() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        a.update([3, 4])
        assert_eq(a.size(), 4)

    func test_update_no_duplicates() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        a.update([2, 3])
        assert_eq(a.size(), 3)

    func test_intersection_update() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        a.intersection_update(C3Utils.HashSet.new([2, 3, 4]))
        assert_eq(a.size(), 2)
        assert_true(a.has(2) and a.has(3))
        assert_false(a.has(1))

    func test_difference_update() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        a.difference_update([2, 3])
        assert_eq(a.size(), 1)
        assert_true(a.has(1))

    func test_symmetric_difference_update() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        a.symmetric_difference_update([2, 3, 4])
        assert_eq(a.size(), 2)
        assert_true(a.has(1) and a.has(4))


class TestComparisons:
    extends GutTest

    func test_equals_same_elements() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := C3Utils.HashSet.new([3, 1, 2])
        assert_true(a.equals(b))

    func test_equals_different_size() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([1, 2, 3])
        assert_false(a.equals(b))

    func test_equals_different_elements() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([1, 3])
        assert_false(a.equals(b))

    func test_issubset_true() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([1, 2, 3])
        assert_true(a.issubset(b))

    func test_issubset_equal_sets() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([1, 2])
        assert_true(a.issubset(b))

    func test_issubset_false() -> void:
        var a := C3Utils.HashSet.new([1, 4])
        var b := C3Utils.HashSet.new([1, 2, 3])
        assert_false(a.issubset(b))

    func test_issuperset_true() -> void:
        var a := C3Utils.HashSet.new([1, 2, 3])
        var b := C3Utils.HashSet.new([1, 2])
        assert_true(a.issuperset(b))

    func test_issuperset_false() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([1, 2, 3])
        assert_false(a.issuperset(b))

    func test_isdisjoint_true() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([3, 4])
        assert_true(a.isdisjoint(b))

    func test_isdisjoint_false() -> void:
        var a := C3Utils.HashSet.new([1, 2])
        var b := C3Utils.HashSet.new([2, 3])
        assert_false(a.isdisjoint(b))

    func test_isdisjoint_empty_is_disjoint_with_anything() -> void:
        var a := C3Utils.HashSet.new()
        var b := C3Utils.HashSet.new([1, 2, 3])
        assert_true(a.isdisjoint(b))
