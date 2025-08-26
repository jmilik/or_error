# or_error

[![Package Version](https://img.shields.io/hexpm/v/or_error)](https://hex.pm/packages/or_error)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/or_error/)

An `OrError` is an ad-hoc error type.  Use `OrError(value)` in functions that may fail.

An `OrError` can be quickly constructed from any type of `Result`.  This makes combining error types from different libraries much easier.  However it comes at the cost of being less typeful: you can't recover the original error value.

Because an `OrError` is just a `Result` with a fixed error type, it forms a monad with a single map function, which is useful for effortlessly handling errors in your codebase.

Further documentation can be found at <https://hexdocs.pm/or_error>.

## Comparison of error handling

`or_error` excels at handling errors of different types.

For a simple comparison, let's try to read an `Int` from a json file using `simplifile` and `gleam/dynamic/decode`.

### Method 1: Nested `Result`s

```gleam
fn read_int(file_path: String) -> Result(Result(Int, json.DecodeError), simplifile.FileError) {
  use content <- result.map(file_path |> simplifile.read())
  content |> json.parse(decode.int)
}
```

This method works, but the return type is unweildy at best.  Pattern matching on it in future is cumbersome.

### Method 2: A custom error type

```gleam
type FileParseError {
  FileReadError(simplifile.FileError)
  JsonParseError(json.DecodeError)
}

fn read_int(file_path: String) -> Result(Int, FileParseError) {
  use content <- result.try(
    file_path
    |> simplifile.read()
    |> result.map_error(fn(read_error) { FileReadError(read_error) }),
  )

  content
  |> json.parse(decode.int)
  |> result.map_error(fn(parse_error) { JsonParseError(parse_error) })
}
```

This flattening of the error types provides a much nicer interface for callers to work with.  However it takes longer to write and eventually results in huge, nested error variant types.

### Method 3: With `or_error`

If we don't care to track the error typefully, we can take a pragmatic approach by converting relevant error information to a human-readable string.

```gleam
fn read_int(file_path: String) -> OrError(Int) {
  use content <-
    file_path
    |> simplifile.read()
    |> or_error.of_result("Failed to read file" <> file_path)
    |> or_error.bind_() // `bind_()` is a pipe-able version of `bind()`

  content
  |> json.parse(decode.int)
  |> or_error.of_result("Failed to parse Int from content")
}
```

To each `or_error.of_result()` call, we pass some human-readable context.  The error itself will also be recorded; it is constructed by `string.inspect(error)`.

This method scales well as codebases become more complex, and error types more numerable.  However, we have lost type information about the errors themselves.

If we were to call `or_error.unwrap_panic()` with this function on a nonexistent file, we would see:

```
runtime error: panic

error: Enoent
context: Failed to read file does_not_exist.json
```

## An (almost drop-in) replacement for `gleam/result`

`or_error` is intended as a replacement for `gleam/result`.

As such, all relevant functions are reimplemented, with a few exceptions:
* `try_recover`: This is omitted since recovering from a string alone is itself error-prone.
* `try`: This is renamed to `bind` in reference to the type's monadic nature.
* `map_error`: Since there is only one error type, which is morally a string, this function does not make sense.
* `unwrap_error`, `unwrap_both` and `replace_error`: Since the error type is not directly usable, there is no purpose to these functions.

Additionally, some other functions are provided, mostly to make code more pipe-friendly:
* `bind_` and `map_`: Pipe-able versions of `bind` and `map`.
* `return`: Equivalent to constructing `Ok`, named in reference to the type's monadic nature.
* `fail`: Allows direct construction of the `Error` case.
* `unwrap_panic`: Panic if the `OrError` is not `Ok`.  A pipe-able alternative for `let assert ...`.
* `pretty_print`: A self-explanatory function, also used by `unwrap_panic`.
* `of_result`: A quick way to construct an `OrError`, using `string.inspect` on any error.

## Installation

Add `or_error` to your Gleam project.

```sh
gleam add or_error
```

## Prior art

This library is inspired by Ocaml's [`Or_error`](https://ocaml.org/p/base/v0.14.1/doc/base/Base/Or_error/index.html) module.
