import gleam/function
import gleam/list
import gleam/option
import gleeunit
import or_error

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn pretty_print_test() {
  let pp =
    or_error.pretty_print(
      or_error.fail(1, "initial context"),
      function.identity,
    )
  assert pp == "error: 1
context: initial context"

  let pp_no_context =
    or_error.pretty_print(or_error.fail(1, ""), function.identity)
  assert pp_no_context == "error: 1"
}

fn double_positives(x: Int) -> or_error.OrError(Int) {
  case { x > 0 } {
    True -> or_error.return(x * 2)
    False -> or_error.fail(x, "not a positive int")
  }
}

pub fn equivalence_of_map_functions() {
  let ok_1 = or_error.return(1)
  let ok_2 = or_error.return(2)
  let via_bind = or_error.bind(ok_2, double_positives)

  use one <- ok_1 |> or_error.bind_()
  let via_use = double_positives(one)

  assert via_bind == via_use
  or_error.return(Nil)
}

pub fn is_ok_test() {
  assert or_error.is_ok(or_error.return(1))

  assert !or_error.is_ok(or_error.fail(1, ""))
}

pub fn is_error_test() {
  assert !or_error.is_error(or_error.return(1))

  assert or_error.is_error(or_error.fail(1, ""))
}

pub fn map_test() {
  assert or_error.map(or_error.return(1), fn(x) { x + 1 }) == or_error.return(2)

  assert or_error.map(or_error.return(1), fn(_) { "2" }) == or_error.return("2")

  assert or_error.map(or_error.fail(1, ""), fn(x) { x + 1 })
    == or_error.fail(1, "")

  use x <- or_error.return(1) |> or_error.map_()
  assert { x + 1 } == 2
}

pub fn bind_test() {
  assert or_error.bind(or_error.fail(1, ""), fn(x) { or_error.return(x + 1) })
    == or_error.fail(1, "")

  assert or_error.bind(or_error.return(1), fn(x) { or_error.return(x + 1) })
    == or_error.return(2)

  assert or_error.bind(or_error.return(1), fn(_) {
      or_error.return("type change")
    })
    == or_error.return("type change")

  assert or_error.bind(or_error.return(1), fn(_) { or_error.fail(1, "") })
    == or_error.fail(1, "")
}

pub fn unwrap_test() {
  assert or_error.unwrap(or_error.return(1), 50) == 1

  assert or_error.unwrap(or_error.fail("", "nope"), 50) == 50
}

pub fn lazy_unwrap_test() {
  assert or_error.lazy_unwrap(or_error.return(1), fn() { 50 }) == 1

  assert or_error.lazy_unwrap(or_error.fail("", "nope"), fn() { 50 }) == 50
}

pub fn or_test() {
  assert or_error.or(or_error.return(1), or_error.return(2))
    == or_error.return(1)

  assert or_error.or(or_error.return(1), or_error.fail("", ""))
    == or_error.return(1)

  assert or_error.or(or_error.fail("", ""), or_error.return(2))
    == or_error.return(2)

  assert or_error.or(or_error.fail("1", ""), or_error.fail("2", ""))
    == or_error.fail("2", "")
}

pub fn lazy_or_test() {
  assert or_error.lazy_or(or_error.return(1), fn() { or_error.return(2) })
    == or_error.return(1)

  assert or_error.lazy_or(or_error.return(1), fn() { or_error.fail("", "") })
    == or_error.return(1)

  assert or_error.lazy_or(or_error.fail("", ""), fn() { or_error.return(2) })
    == or_error.return(2)

  assert or_error.lazy_or(or_error.fail("", ""), fn() { or_error.fail("", "") })
    == or_error.fail("", "")
}

pub fn all_test() {
  assert or_error.all([
      or_error.return(1),
      or_error.return(2),
      or_error.return(3),
    ])
    == or_error.return([1, 2, 3])

  assert or_error.all([
      or_error.return(1),
      or_error.fail("", "a"),
      or_error.fail("", "b"),
      or_error.return(3),
    ])
    == or_error.fail("", "a")
}

pub fn partition_test() {
  assert or_error.partition([]) == #([], [])

  assert or_error.partition([
      or_error.return(1),
      or_error.return(2),
      or_error.return(3),
    ])
    == #([3, 2, 1], [])

  assert or_error.partition([
      or_error.fail("", "a"),
      or_error.fail("", "b"),
      or_error.fail("", "c"),
    ])
    == #([], [
      or_error.ErrorInfo("\"\"", option.Some("c")),
      or_error.ErrorInfo("\"\"", option.Some("b")),
      or_error.ErrorInfo("\"\"", option.Some("a")),
    ])

  assert or_error.partition([
      or_error.return(1),
      or_error.fail("", "a"),
      or_error.return(2),
      or_error.fail("", "b"),
      or_error.fail("", "c"),
    ])
    == #([2, 1], [
      or_error.ErrorInfo("\"\"", option.Some("c")),
      or_error.ErrorInfo("\"\"", option.Some("b")),
      or_error.ErrorInfo("\"\"", option.Some("a")),
    ])

  // TCO test
  let _ =
    list.repeat(or_error.return(1), 1_000_000)
    |> or_error.partition

  list.repeat(or_error.fail("", "a"), 1_000_000)
  |> or_error.partition
}

pub fn replace_test() {
  assert or_error.replace(or_error.return(Nil), "OK") == or_error.return("OK")
}

pub fn replace_with_ok_test() {
  assert or_error.replace(or_error.fail(Nil, ""), "Invalid")
    == or_error.fail(Nil, "")
}

pub fn values_test() {
  assert or_error.values([
      or_error.return(1),
      or_error.fail("", ""),
      or_error.return(3),
    ])
    == [1, 3]
}
