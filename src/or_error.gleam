/// A specialization of the builtin `Result` type: the error type is always `ErrorInfo`.
///
/// This makes combining different types of Error much easier.  However it comes at the cost of being less typeful: you can't recover the original error value.
///
/// This choice also means that `OrError` forms a monad with a single map function, which is useful for propagating errors.
import gleam/list
import gleam/option
import gleam/string

/// The sole inhabitant of `Error`.
///
/// `error` is the result of `string.inspect` on the error value.
/// `context` is an optional human-readable value for providing information about the error.
pub type ErrorInfo {
  ErrorInfo(error: String, context: option.Option(String))
}

pub type OrError(a) =
  Result(a, ErrorInfo)

fn pretty_print_error_info(error_info: ErrorInfo) -> String {
  let ErrorInfo(error, context) = error_info
  let error_str = "error: " <> error
  case context {
    option.Some(s) -> {
      error_str <> "
context: " <> s
    }
    option.None -> error_str
  }
}

/// A function to prettily print the or_error.
pub fn pretty_print(or_error: OrError(a), using: fn(a) -> String) -> String {
  case or_error {
    Ok(a) -> using(a)
    Error(e) -> pretty_print_error_info(e)
  }
}

/// The monadic map function.
///
/// Updates a value held within the `Ok` constructor by calling the given function on it.
///
/// If the or_error is an `Error` rather than `Ok` the function is not called and the or_error stays the same.
pub fn map(or_error: OrError(a), f: fn(a) -> b) -> OrError(b) {
  case or_error {
    Ok(a) -> Ok(f(a))
    Error(e) -> Error(e)
  }
}

/// A version of `map` for piping to for `use`.
pub fn map_() -> fn(OrError(a)) -> fn(fn(a) -> b) -> OrError(b) {
  fn(or_error) { fn(f) { map(or_error, f) } }
}

/// The monadic bind function.
///
/// Updates a value held within the `Ok` constructor by calling the given `OrError`-returning function on it.
///
/// If the or_error is an `Error` rather than `Ok` the function is not called and the or_error stays the same.
pub fn bind(or_error: OrError(a), f: fn(a) -> OrError(b)) -> OrError(b) {
  case or_error {
    Ok(a) -> f(a)
    Error(e) -> Error(e)
  }
}

/// A version of `bind` for piping to for `use`.
pub fn bind_() -> fn(OrError(a)) -> fn(fn(a) -> OrError(b)) -> OrError(b) {
  fn(or_error) { fn(f) { bind(or_error, f) } }
}

/// The monad return function.
///
/// Allows construction of an `Ok` value.
pub fn return(a: a) -> OrError(a) {
  Ok(a)
}

/// Merges a nested `OrError` into a single layer.
pub fn flatten(result: OrError(OrError(a))) -> OrError(a) {
  case result {
    Ok(x) -> x
    Error(error) -> Error(error)
  }
}

/// Allows construction of an `Error` value as the `ErrorInfo` type.
///
/// The `error` field is constructed by calling `string.inspect` on the passed error value.
///
/// The optional `context` field is to allow developers to provide information on the error occurred.
/// If the empty string is passed, the context field will be set to `None`.
pub fn fail(e: e, context: String) {
  let error = string.inspect(e)
  let context = case context {
    "" -> option.None
    s -> option.Some(s)
  }
  Error(ErrorInfo(error: error, context: context))
}

/// A helper function to allow easy construction of `OrError` from a `Result`.
/// If the result is an `Error`, the `ErrorInfo` will be construced by `fail`.
pub fn of_result(result: Result(a, e), context: String) -> OrError(a) {
  case result {
    Ok(a) -> Ok(a)
    Error(e) -> fail(e, context)
  }
}

/// Checks whether the or_error is an `Ok` value.
pub fn is_ok(or_error: OrError(a)) -> Bool {
  case or_error {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Checks whether the or_error is an `Error` value.
pub fn is_error(or_error: OrError(a)) -> Bool {
  case or_error {
    Ok(_) -> False
    Error(_) -> True
  }
}

/// Extracts the `Ok` value from an or_error, returning a default value if the or_error is an `Error`.
pub fn unwrap(or_error: OrError(a), default: a) -> a {
  case or_error {
    Ok(a) -> a
    Error(_) -> default
  }
}

/// Extracts the `Ok` value from an or_error, evaluating the default function if the or_error is an `Error`.
pub fn lazy_unwrap(or_error: OrError(a), default: fn() -> a) -> a {
  case or_error {
    Ok(a) -> a
    Error(_) -> default()
  }
}

/// Extracts the `Ok` value from an or_error, panicing if the or_error is an `Error`.
pub fn unwrap_panic(or_error: OrError(a)) -> a {
  case or_error {
    Ok(a) -> a
    Error(e) -> panic as pretty_print_error_info(e)
  }
}

/// Returns the first value if it is Ok, otherwise returns the second value.
pub fn or(first: OrError(a), second: OrError(a)) -> OrError(a) {
  case first {
    Ok(_) -> first
    Error(_) -> second
  }
}

/// Returns the first value if it is `Ok`, otherwise evaluates the given function for a fallback value.
pub fn lazy_or(first: OrError(a), second: fn() -> OrError(a)) -> OrError(a) {
  case first {
    Ok(_) -> first
    Error(_) -> second()
  }
}

/// Combines a list of or_errors into a single or_error.
///
/// If all elements in the list are `Ok` then returns an `Ok` holding the list of values.
/// If any element is `Error` then returns the first error.
pub fn all(or_errors: List(OrError(a))) -> OrError(List(a)) {
  case { list.try_map(or_errors, to_result) } {
    Ok(oks) -> Ok(oks)
    Error(e) -> Error(e)
  }
}

fn to_result(or_error: OrError(a)) -> Result(a, ErrorInfo) {
  case or_error {
    Ok(a) -> Ok(a)
    Error(e) -> Error(e)
  }
}

/// Given a list of or_errors, returns a pair where the first element is a list
/// of all the values inside `Ok` and the second element is a list with all the
/// values inside `Error`.
///
/// The values in both lists appear in reverse order with respect to their
/// position in the original list of or_errors.
pub fn partition(or_errors: List(OrError(a))) -> #(List(a), List(ErrorInfo)) {
  partition_loop(or_errors, [], [])
}

fn partition_loop(
  or_errors: List(OrError(a)),
  oks: List(a),
  errors: List(ErrorInfo),
) {
  case or_errors {
    [] -> #(oks, errors)
    [Ok(a), ..rest] -> partition_loop(rest, [a, ..oks], errors)
    [Error(e), ..rest] -> partition_loop(rest, oks, [e, ..errors])
  }
}

/// Replace the value inside `Ok`.  Does nothing if the or_error is an `Error`.
pub fn replace(or_error: OrError(a), value: b) -> OrError(b) {
  case or_error {
    Ok(_) -> Ok(value)
    Error(e) -> Error(e)
  }
}

/// Given a list of or_errors, returns only the values inside Ok.
pub fn values(or_errors: List(OrError(a))) -> List(a) {
  list.filter_map(or_errors, to_result)
}
