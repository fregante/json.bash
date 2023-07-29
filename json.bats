#!/usr/bin/env bats
# shellcheck shell=bash
set -u -o pipefail

bats_require_minimum_version 1.5.0

load json.bash

setup() {
  cd "${BATS_TEST_DIRNAME:?}"
}

function mktemp_bats() {
  mktemp "${BATS_RUN_TMPDIR:?}/json.bats.XXX" "$@"
}

@test "json.buffer_output :: out stream :: in args" {
  [[ $(json.buffer_output foo) == "foo" ]]
  [[ $(json.buffer_output foo "bar baz" $'boz\n123') == $'foobar bazboz\n123' ]]
}

@test "json.buffer_output :: out stream :: in array" {
  local input=(foo)
  [[ $(in=input json.buffer_output) == "foo" ]]
  input=(foo "bar baz" $'boz\n123')
  [[ $(in=input json.buffer_output) == $'foobar bazboz\n123' ]]
}

@test "json.buffer_output :: out array :: in array" {
  local buff input=()
  out=buff in=input json.buffer_output
  [[ ${#buff[@]} == 0 ]]

  input=(foo)
  out=buff in=input json.buffer_output
  [[ ${#buff[@]} == 1 && ${buff[0]} == "foo" ]]

  input=("bar baz" $'boz\n123')
  out=buff in=input json.buffer_output
  [[ ${#buff[@]} == 3 && ${buff[0]} == "foo" && ${buff[1]} == "bar baz" \
    && ${buff[2]} == $'boz\n123' ]]
}

@test "json.buffer_output :: out array :: in args" {
  local buff input=()

  out=buff json.buffer_output "foo"
  [[ ${#buff[@]} == 1 && ${buff[0]} == "foo" ]]

  out=buff json.buffer_output "bar baz" $'boz\n123'
  [[ ${#buff[@]} == 3 && ${buff[0]} == "foo" && ${buff[1]} == "bar baz" \
    && ${buff[2]} == $'boz\n123' ]]
}

@test "json.buffer_output :: errors" {
  local buff
  # in=arrayname must be set when 0 args are passed. Explicitly calling with 0
  # args is a no-op, and when calling with dynamic args an array ref should be
  # used for efficiency.
  run json.buffer_output
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  out=buff run json.buffer_output
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]
}

@test "json.encode_string" {
  run json.encode_string
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  join=,
  [[ $(json.encode_string "") == '""' ]]
  [[ $(json.encode_string foo) == '"foo"' ]]
  [[ $(json.encode_string foo $'bar\nbaz\tboz\n') == '"foo","bar\nbaz\tboz\n"' ]]
  [[ $(join=$'\n' json.encode_string foo $'bar\nbaz\tboz\n') \
    ==  $'"foo"\n"bar\\nbaz\\tboz\\n"' ]]

  local buff=()
  empty=()
  out=buff in=empty json.encode_string
  [[ ${buff[*]} == "" ]]

  buff=()
  out=buff json.encode_string ""
  [[ ${#buff[@]} == 1 && ${buff[0]} == '""' ]]

  out=buff json.encode_string "foo"
  [[ ${#buff[@]} == 2 && ${buff[0]} == '""' && ${buff[1]} == '"foo"' ]]

  out=buff join= json.encode_string $'bar\nbaz' boz
  [[ ${#buff[@]} == 4 && ${buff[0]} == '""' && ${buff[1]} == '"foo"' \
    && ${buff[2]} == $'"bar\\nbaz"' && ${buff[3]} == '"boz"' ]]

  out=buff join=, json.encode_string abc def
  [[ ${#buff[@]} == 5 && ${buff[4]} == '"abc","def"' ]]

  local input=()
  in=input run json.encode_string
  [[ $status == 0 && $output == '' ]]

  input=(foo $'bar\nbaz\tboz\n')
  [[ $(in=input json.encode_string) == '"foo","bar\nbaz\tboz\n"' ]]
}

# A string containing all bytes (other than 0, which bash can't hold in vars)
function all_bytes() {
  python3 -c 'print("".join(chr(c) for c in range(1, 256)))'
}

# Verify that the first arg is a JSON string containing bytes 1..255 inclusive
function assert_is_all_bytes_json() {
  all_bytes_json="${1:?}" python3 <<< '
import json, os

actual = json.loads(os.environ["all_bytes_json"])
expected = "".join(chr(c) for c in range(1, 256))

if actual != expected:
  raise AssertionError(
    f"Decoded JSON chars did not match:\n  {actual=!r}\n{expected=!r}"
  )
  '
}

@test "json.encode_string :: all bytes (other than zero)" {
  # Check we can encode all bytes (other than 0, which bash can't hold in vars)
  bytes=$(all_bytes)
  # json.encode_string has 3 code paths which we need to test:

  # 1. single strings
  all_bytes_json=$(json.encode_string "${bytes:?}")
  assert_is_all_bytes_json "${all_bytes_json:?}"

  # 2. multiple strings with un-joined output
  buff=()
  out=buff json.encode_string "${bytes:?}" "${bytes:?}"
  assert_is_all_bytes_json "${buff[0]:?}"
  assert_is_all_bytes_json "${buff[1]:?}"
  [[ ${#buff[@]} == 2 ]]

  # 3. multiple strings with joined output
  output=$(join=, json.encode_string "${bytes:?}" "${bytes:?}")
  [[ $output == "${buff[0]},${buff[1]}" ]]
}

@test "json.encode_number" {
  local buff input join
  run json.encode_number
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  run json.encode_number ''
  [[ $status == 1 && $output == *"not all inputs are numbers: ''" ]]

  input=('')
  in=input run json.encode_number
  [[ $status == 1 && $output == *"not all inputs are numbers: ''" ]]

  input=()
  in=input run json.encode_number
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_number 42) == "42" ]]
  [[ $(json.encode_number -1.34e+4 2.1e-4 2e6) == "-1.34e+4,2.1e-4,2e6" ]]

  input=(-1.34e+4 2.1e-4 2e6)
  [[ $(in=input json.encode_number) == "-1.34e+4,2.1e-4,2e6" ]]

  run json.encode_number foo bar
  [[ $status == 1 ]]
  [[ $output == "json.encode_number(): not all inputs are numbers: 'foo' 'bar'" ]]
  run json.encode_bool 42,42
  [[ $status == 1 ]]

  buff=()
  out=buff join= json.encode_number 1
  out=buff join= json.encode_number 2 3
  out=buff join=$'\n' json.encode_number 4 5
  [[ ${#buff[@]} == 4 && ${buff[0]} == '1' && ${buff[1]} == '2' \
    && ${buff[2]} == '3' && ${buff[3]} == $'4\n5' ]]
}

@test "json.encode_bool" {
  local buff input join
  run json.encode_bool
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_bool
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_bool true) == "true" ]]
  [[ $(json.encode_bool false) == "false" ]]
  [[ $(json.encode_bool false true) == "false,true" ]]

  input=(false true)
  [[ $(in=input json.encode_bool) == "false,true" ]]

  run json.encode_bool foo bar
  [[ $status == 1 ]]
  [[ $output == "json.encode_bool(): not all inputs are bools: 'foo' 'bar'" ]]
  run json.encode_bool true,true
  [[ $status == 1 ]]

  buff=()
  out=buff join= json.encode_bool true
  out=buff join= json.encode_bool false true
  out=buff join=$'\n' json.encode_bool true false
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'true' && ${buff[1]} == 'false' \
    && ${buff[2]} == 'true' && ${buff[3]} == $'true\nfalse' ]]
}

@test "json.encode_null" {
  local buff input join
  run json.encode_null
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_null
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_null null) == "null" ]]
  [[ $(json.encode_null null null) == "null,null" ]]

  input=(null null)
  [[ $(in=input json.encode_null) == "null,null" ]]

  run json.encode_null foo bar
  [[ $status == 1 ]]
  [[ $output == "json.encode_null(): not all inputs are null: 'foo' 'bar'" ]]
  run json.encode_null null,null
  [[ $status == 1 ]]

  buff=()
  out=buff join= json.encode_null null
  out=buff join= json.encode_null null null
  out=buff join=$'\n' json.encode_auto null null
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'null' && ${buff[1]} == 'null' \
    && ${buff[2]} == 'null' && ${buff[3]} == $'null\nnull' ]]
}

@test "json.encode_auto" {
  local buff input join
  run json.encode_auto
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_auto
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_auto 42) == '42' ]]
  [[ $(json.encode_auto hi) == '"hi"' ]]
  [[ $(json.encode_auto true) == 'true' ]]
  [[ $(json.encode_auto true hi 42) == 'true,"hi",42' ]]
  [[ $(json.encode_auto true,false foo bar 42) == '"true,false","foo","bar",42' ]]
  [[ $(json.encode_auto '"42') == '"\"42"' ]]
  [[ $(json.encode_auto ',"42') == '",\"42"' ]]
  [[ $(json.encode_auto foo '"42' foo '"42') == '"foo","\"42","foo","\"42"' ]]
  [[ $(json.encode_auto foo ',"42' foo ',"42') == '"foo",",\"42","foo",",\"42"' ]]

  input=(foo ',"42' foo ',"42')
  [[ $(in=input json.encode_auto) == '"foo",",\"42","foo",",\"42"' ]]

  buff=()
  out=buff join= json.encode_auto null
  out=buff join= json.encode_auto hi 42
  out=buff join=$'\n' json.encode_auto abc true
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'null' && ${buff[1]} == '"hi"' \
    && ${buff[2]} == '42' && ${buff[3]} == $'"abc"\ntrue' ]]
}

@test "json.encode_raw" {
  local buff join input
  run json.encode_raw
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_raw
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_raw '{}') == '{}' ]]
  # invalid JSON is not checked/detected
  [[ $(json.encode_raw '}') == '}' ]]
  [[ $(json.encode_raw '[]' '{}') == '[],{}' ]]

  input=('[]' '{}')
  [[ $(in=input json.encode_raw) == '[],{}' ]]

  run json.encode_raw ''
  echo $output >&2
  [[ $status == 1 ]]
  [[ $output =~ "raw JSON value is empty" ]]

  buff=()
  out=buff join= json.encode_raw 1
  out=buff join= json.encode_raw 2 3
  out=buff join=$'\n' json.encode_raw 4 5
  declare -p buff
  [[ ${#buff[@]} == 4 && ${buff[0]} == '1' && ${buff[1]} == '2' \
    && ${buff[2]} == '3' && ${buff[3]} == $'4\n5' ]]
}
@test "json.encode_json :: in must be set with no args" {
  run json.encode_json
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]
}

@test "json.encode_json" {
  local join=','
  [[ $(json.encode_json '{}') == '{}' ]]
  [[ $(json.encode_json '{"foo":["bar","baz"]}') == '{"foo":["bar","baz"]}' ]]
  [[ $(json.encode_json '[123]') == '[123]' ]]
  [[ $(json.encode_json '"hi"') == '"hi"' ]]
  [[ $(json.encode_json '-1.34e+4') == '-1.34e+4' ]]
  [[ $(json.encode_json 'true') == 'true' ]]
  [[ $(json.encode_json 'null') == 'null' ]]
  [[ $(json.encode_json '{"a":1}' '{"b":2}') == '{"a":1},{"b":2}' ]]

  join=''
  [[ $(json.encode_json 'true' '42') == 'true42' ]]

  local buff=() input=()
  out=buff in=input json.encode_json
  [[ ${#buff[@]} == 0 ]]

  input=(42 '"hi"')
  out=buff in=input json.encode_json
  [[ ${#buff[@]} == 2 && ${buff[0]} == '42' && ${buff[1]} == '"hi"' ]]

  join=','
  out=buff in=input json.encode_json
  declare -p buff
  [[ ${#buff[@]} == 3 && ${buff[0]} == '42' && ${buff[1]} == '"hi"' \
    && ${buff[2]} == '42,"hi"' ]]
}

@test "json.encode_json :: recognises valid JSON with insignificant whitespace" {
  local buff
  out=buff json.encode_json ' { "foo" : [ "bar" , 42 ] , "baz" : true } '
  [[ ${#buff[@]} == 1 \
    && ${buff[0]} == ' { "foo" : [ "bar" , 42 ] , "baz" : true } ' ]]
}

@test "json.encode_json :: rejects invalid JSON" {
  invalid_json=('{:}' ' ' '[' '{' '"foo' '[true false]')

  for invalid in "${invalid_json[@]:?}"; do
    run json.encode_json ''
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    run json.encode_json "${invalid:?}"
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    run json.encode_json '"ok"' "${invalid:?}"
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    run json.encode_json "${invalid:?}" '"ok"'
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    local -i tests+=4
  done

  (( ${tests:?} == 4 * 6 ))
}

function assert_encode_object_entries_from_pre_encoded_entries() {
  printf -v expected_str '%s' "${expected[@]}"
  [[ $(type=${type:?} in=${in:?} json.encode_object_entries) \
    == "${expected_str?}" ]]

  local buff=()
  type=${type:?} in=${in:?} out=buff json.encode_object_entries
  assert_array_equals expected buff
}

@test "json.encode_object_entries :: from pre-encoded entries" {
  local entries=() expected

  # No entries produce no outputs (specifically, no empty string output)
  entries=() expected=()
  type=string in=entries assert_encode_object_entries_from_pre_encoded_entries

  # Only empty objects also produce no outputs
  entries=('{}' '{  }' $'  \t\n\r { \t\n\r } \t\n\r ') expected=()
  type=string in=entries assert_encode_object_entries_from_pre_encoded_entries

  entries=('{"a":"x"}' '{}' '{"b":"y","c":"z"}') expected=('"a":"x","b":"y","c":"z"')
  type=string in=entries assert_encode_object_entries_from_pre_encoded_entries

  entries=('{}' '{"a":[{"x":true}]}' '{}' '{"b":42,"c":false}' '{}')
  expected=('"a":[{"x":true}],"b":42,"c":false')
  type=json in=entries  assert_encode_object_entries_from_pre_encoded_entries
}

@test "json.encode_object_entries" {
  [[ $(type=string json.encode_object_entries 'a b' '1 2'  c d) == '"a b":"1 2","c":"d"' ]]
  [[ $(type=number json.encode_object_entries a 1 c 2) == '"a":1,"c":2' ]]
  [[ $(type=bool json.encode_object_entries a true c false) == '"a":true,"c":false' ]]
  [[ $(type=true json.encode_object_entries a true c true) == '"a":true,"c":true' ]]
  [[ $(type=false json.encode_object_entries a false c false) == '"a":false,"c":false' ]]
  [[ $(type=null json.encode_object_entries a null c null) == '"a":null,"c":null' ]]
  [[ $(type=json json.encode_object_entries a '{"b":42}' c [1,2]) == '"a":{"b":42},"c":[1,2]' ]]
  [[ $(type=raw json.encode_object_entries a '{"b":42}' c [1,2]) == '"a":{"b":42},"c":[1,2]' ]]

  local k=(a b) v_str=('foo bar' 42) v_json=('{}' true)
  [[ $(type=string in=k,v_str json.encode_object_entries) == '"a":"foo bar","b":"42"' ]]
  [[ $(type=json in=k,v_json json.encode_object_entries) == '"a":{},"b":true' ]]

  local -A kv=([a]='foo bar' [b]='bar baz')
  # order of associative array keys is not defined
  { printf '{'; type=string in=kv json.encode_object_entries; printf '}'; } \
    | compare=parsed equals_json '{a: "foo bar", b: "bar baz"}'

  local buff=()
  out=buff type=string in=k,v_str json.encode_object_entries
  [[ $(printf '%s' "${buff[@]}") == '"a":"foo bar","b":"42"' ]]
}

@test "json.encode_object_entries :: escapes" {
  # When encoding from separate key value arrays, the implementation uses printf
  # to consume bash arrays without running bash ops for each array element. This
  # has the potential to mangle data if we don't escape format strings correctly
  local buff
  buff=(); out=buff type=string json.encode_object_entries $'a\nb\x10c' $'d\te\x01f'
  [[ $(printf '%s' "${buff[@]}") == '"a\nb\u0010c":"d\te\u0001f"' ]]
}

@test "json.encode_object_entries :: non-errors" {
  # pre-encoded entries of type raw are not validated. But the braces surrounding
  # entries are still removed, and empty values ignored without introducing commas
  local entries=('"a":null}' '' '"b":1' '{"foo":"bar"')
  type=raw in=entries json.encode_object_entries
  [[ $(type=raw in=entries json.encode_object_entries) \
    == '"a":null,"b":1,"foo":"bar"' ]]
}

@test "json.encode_object_entries :: errors" {
  run json.encode_object_entries
  [[ $status == 1 && $output == *"\$type must be provided"* ]]

  type=string run json.encode_object_entries
  [[ $status == 1 && $output == *'$in must be set if arguments are not provided' ]]

  local k=() v=()
  # no values specified
  in=k, type=string run json.encode_object_entries
  [[ $status == 1 && $output == *"k,': invalid variable name for name reference"* ]]

  # unequal number of keys / values
  k=(foo)
  in=k,v type=string  run json.encode_object_entries
  [[ $status == 1 && $output == *'unequal number of keys and values: 1 keys, 0 values' ]]

  # unequal number of keys / values via arguments
  type=string run json.encode_object_entries a
  [[ $status == 1 && $output == *'number of arguments is odd - not all keys have values' ]]

  # pre-encoded entries must be of the stated type
  local entries=('{"a":null}')
  type=string in=entries run json.encode_object_entries
  [[ $status == 1 && $output == "json.encode_object_entries(): provided entries \
are not all valid JSON objects with 'string' values." ]]
}

# Verify that a json.encode_${type} function handles in & out parameters correctly
function assert_input_encodes_to_output_under_all_calling_conventions() {
  : "${input?}" "${output:?}" "${join?}"
  local buff1=() buff2=() IFS
  local stdout1=$(mktemp_bats); local stdout2=$(mktemp_bats)
  # Note: join is passed implicitly/automatically

  # There are 4 ways to call - {in array, in args} x {out stdout, out array}
  out=''    in=''    "json.encode_${type:?}" "${input[@]}"   > "${stdout1:?}"
  out=''    in=input "json.encode_${type:?}"                 > "${stdout2:?}"
  out=buff1 in=''    "json.encode_${type:?}" "${input[@]}"
  out=buff2 in=input "json.encode_${type:?}"


  IFS=${join?}; joined_output=${output[*]}
  echo -n "$joined_output" | diff -u - "${stdout1:?}"
  echo -n "$joined_output" | diff -u - "${stdout2:?}"

  # When a join character is set, the encode fn joins inputs and outputs 1 result
  if [[ $join ]]; then
    [[ ${#buff1[@]} == 1 ]]
    [[ ${#buff2[@]} == 1 ]]
    [[ ${buff1[0]} == "${joined_output:?}" ]]
    [[ ${buff2[0]} == "${joined_output:?}" ]]
  else
    [[ ${#buff1[@]} == "${#output[@]}" ]]
    [[ ${#buff2[@]} == "${#output[@]}" ]]
    for i in "${!buff1[@]}"; do
      [[ ${buff1[$i]} == "${output[$i]}" ]]
      [[ ${buff2[$i]} == "${output[$i]}" ]]
    done
  fi
}

@test "json.encode_* in/out calling convention" {
  # Verify that the encode functions correctly handle in and out parameters
  local input=() buff=()
  local -A examples=(
    [string_in]=$'a b\nc d\n \n' [string_out]='"a b\nc d\n \n"'
    [number_in]='-42.4e2'        [number_out]='-42.4e2'
    [bool_in]='false'            [bool_out]='false'
    [true_in]='true'             [true_out]='true'
    [false_in]='false'           [false_out]='false'
    [null_in]='null'             [null_out]='null'
    [auto_in]='hi'               [auto_out]='"hi"'
    [raw_in]='{"msg":"hi"}'      [raw_out]='{"msg":"hi"}'
    [json_in]='{"msg":"hi"}'     [json_out]='{"msg":"hi"}'
  )

  # for type in auto; do
  for type in string number bool true false null auto raw json; do
    raw="${examples[${type:?}_in]:?}" enc="${examples[${type:?}_out]:?}"

    if [[ $type != @(string|auto) ]]; then
      run "json.encode_${type:?}" ''
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]

      out=buff run "json.encode_${type:?}" ''
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]

      input=('')
      in=input run "json.encode_${type:?}"
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]

      in=input out=buff run "json.encode_${type:?}"
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]
    else
      # Single empty
      input=('') output=('""')
      join=''  assert_input_encodes_to_output_under_all_calling_conventions
      join=',' assert_input_encodes_to_output_under_all_calling_conventions
    fi

    # Multiple inputs
    input=("${raw:?}" "${raw:?}") output=("${enc:?}" "${enc:?}")
    join=''  assert_input_encodes_to_output_under_all_calling_conventions
    join=',' assert_input_encodes_to_output_under_all_calling_conventions
    # Multiple inputs
    input=("${raw:?}" "${raw:?}") output=("${enc:?}" "${enc:?}")
    join=''  assert_input_encodes_to_output_under_all_calling_conventions
    join=',' assert_input_encodes_to_output_under_all_calling_conventions
  done
}

@test "json.stream_encode_string" {
  local json_chunk_size=2 buff=()
  for json_chunk_size in '' 2; do
    run json.stream_encode_string < <(printf 'foo')
    [[ $status == 0 && $output == '"foo"' ]]

    run json.stream_encode_string < <(printf 'foo bar\nbaz boz\nabc')
    [[ $status == 0 && $output == '"foo bar\nbaz boz\nabc"' ]]
  done

  # out_cb names a function that's called for each encoded chunk
  stdout_file=$(mktemp_bats)
  json_chunk_size=2
  out=buff out_cb=__json.stream_encode_cb json.stream_encode_string \
    < <(printf 'abcdefg') > "${stdout_file:?}"

  # out_cb is called incrementally. It's not called after the initial or ending
  # " though.
  [[ $(<"${stdout_file:?}") == $'CB: ab\nCB: cd\nCB: ef\nCB: g' ]]

  [[ ${#buff[@]} == 6 && ${buff[0]} == '"' && ${buff[1]} == 'ab' \
    && ${buff[2]} == 'cd' && ${buff[3]} == 'ef' && ${buff[4]} == 'g' \
    && ${buff[5]} == '"'  ]]
}

function __json.stream_encode_cb() {
  printf 'CB: %s\n' "${buff[-1]}"
}

@test "json.stream_encode_raw" {
  local json_chunk_size=2 buff=()
  for json_chunk_size in '' 2; do
    # As with json.encode_raw, it fails if the input is empty
    run json.stream_encode_raw < <(printf '')
    [[ $status == 1 && $output == \
      'json.stream_encode_raw(): raw JSON value is empty' ]]

    run json.stream_encode_raw < <(printf '{"foo":true}')
    echo "$status $output"
    [[ $status == 0 && $output == '{"foo":true}' ]]

    # Trailing newlines are not striped from file contents
    diff <(json.stream_encode_raw < <(printf '{\n  "foo": true\n}\n')) \
         <(printf '{\n  "foo": true\n}\n')
  done

  # out_cb names a function that's called for each encoded chunk
  stdout_file=$(mktemp_bats)
  json_chunk_size=2
  out=buff out_cb=__json.stream_encode_cb json.stream_encode_raw \
    < <(printf '["abc"]') > "${stdout_file:?}"

  [[ $(<"${stdout_file:?}") == $'CB: ["\nCB: ab\nCB: c"\nCB: ]' ]]

  [[ ${#buff[@]} == 4 && ${buff[0]} == '["' && ${buff[1]} == 'ab' \
    && ${buff[2]} == 'c"' && ${buff[3]} == ']' ]]
}

function get_value_encode_examples() {
  example_names=(string_notrim string_trim number bool{1,2} true false null auto{1,2} raw json)
  examples+=(
    # json.stream_encode_string preserves trailing whitespace/newlines
    [string_notrim_in]=$'a b\nc d\n \n' [string_notrim_out]='"a b\nc d\n \n"' [string_notrim_type]=string [string_notrim_cb]=2
    # json.encode_value_from_file trims trailing whitespace. However it's not
    # currently called via json(), because json.encode_from_file always uses
    # json.stream_encode_string.
    [string_trim_in]=$'a b\nc d\n \n'   [string_trim_out]='"a b\nc d"'        [string_trim_type]=string

    [number_in]='-42.4e2'        [number_out]='-42.4e2'
    [bool1_in]='true'            [bool1_out]='true'             [bool1_type]=bool
    [bool2_in]='false'           [bool2_out]='false'            [bool2_type]=bool
    [true_in]='true'             [true_out]='true'
    [false_in]='false'           [false_out]='false'
    [null_in]='null'             [null_out]='null'
    [auto1_in]='hi'              [auto1_out]='"hi"'             [auto1_type]=auto
    [auto2_in]='42'              [auto2_out]='42'               [auto2_type]=auto
    [raw_in]='{"msg":"hi"}'      [raw_out]='{"msg":"hi"}'       [raw_cb]=2
    [json_in]='{"msg":"hi"}'     [json_out]='{"msg":"hi"}'
  )
}

@test "json.encode_value_from_file" {
  local actual buff json_chunk_size=8 cb_count=0
  local example_names; local -A examples; get_value_encode_examples

  for name in "${example_names[@]:?}"; do
    type=${examples[${name}_type]:-${name:?}}

    # json.encode_value_from_file trims whitespace from the file contents before
    # encoding.
    if [[ $name == string_notrim ]]; then continue; fi

    # output to stdout
    out='' type=${type:?} run json.encode_value_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" )
    [[ $status == 0 && $output == "${examples[${name:?}_out]:?}" ]]

    # output to array
    buff=()
    out=buff type=${type:?} json.encode_value_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" )

    printf "expected:\n%s\n" "${examples[${name:?}_out]:?}"
    printf "actual:\n%s\n" "${buff[0]}"

    [[ $status == 0 && ${#buff[@]} == 1 \
      && ${buff[0]} == "${examples[${name:?}_out]:?}" ]]
  done
}

@test "json.encode_value_from_file :: stops reading after null byte" {
  type=string run json.encode_value_from_file \
      < <(printf "foo\x00"; timeout 3 yes )
  [[ $status == 0 && $output == '"foo"' ]]
}

@test "json.encode_from_file :: single value" {
  local actual buff json_chunk_size=8 cb_count
  local tmp=$(mktemp_bats)
  local example_names; local -A examples; get_value_encode_examples

  for name in "${example_names[@]:?}"; do
    type=${examples[${name}_type]:-${name:?}}

    # When encoding strings, json.encode_from_file always uses
    # json.stream_encode_string, never json.encode_value_from_file, so it
    # preserves trailing whitespace.
    if [[ $name == string_trim ]]; then continue; fi

    # output to stdout
    cb_count=0
    type=${type:?} out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" ) > "${tmp:?}"
    echo -n "${examples[${name:?}_out]:?}" | diff - "${tmp:?}"
    [[ $cb_count == ${examples[${name:?}_cb]:-0} ]]

    # output to array
    buff=() cb_count=0
    out=buff type=${type:?} out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" )
    printf -v actual '%s' "${buff[@]}"
    [[ $actual == "${examples[${name:?}_out]:?}" ]]
    [[ $cb_count == ${examples[${name:?}_cb]:-0} ]]
  done
}

function _increment_cb_count() { let ++cb_count; }

function get_array_encode_examples() {
  example_names=(string number bool true false null auto raw json)
  examples+=(
    [string_in]=$'a b\nc d\n \n'        [string_out]=$'"a b","c d"," "'
    [number_in]=$'1\n2\n3\n'            [number_out]=$'1,2,3'
    [bool_in]=$'true\nfalse\nfalse\n'   [bool_out]=$'true,false,false'
    [true_in]=$'true\ntrue\ntrue\n'     [true_out]=$'true,true,true'
    [false_in]=$'false\nfalse\nfalse\n' [false_out]=$'false,false,false'
    [null_in]=$'null\nnull\nnull\n'     [null_out]=$'null,null,null'
    [auto_in]=$'hi\n42\ntrue\nnull\n'   [auto_out]=$'"hi",42,true,null'
    [raw_in]=$'{"msg":"hi"}\n42\n[]\n'  [raw_out]=$'{"msg":"hi"},42,[]'
    [json_in]=$'{"msg":"hi"}\n42\n[]\n' [json_out]=$'{"msg":"hi"},42,[]'
  )
}

@test "json.encode_from_file :: array" {
  local json_buffered_chunk_count=2 cb_count
  local tmp=$(mktemp_bats)
  local example_names; local -A examples; get_array_encode_examples

  for type in "${example_names[@]:?}"; do
    # output to stdout
    cb_count=0
    collection=array split=$'\n' out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${type:?}_in"]}" ) > "${tmp:?}"
    diff <(echo -n "[${examples[${type:?}_out]:?}]") "${tmp:?}"
    [[ $cb_count == 2 ]]

    # output to array
    buff=() cb_count=0
    out=buff collection=array split=$'\n' out_cb=_increment_cb_count \
      json.encode_from_file < <(echo -n "${examples["${type:?}_in"]}" )
    printf -v actual '%s' "${buff[@]}"
    [[ "${actual:?}" == "[${examples[${type:?}_out]:?}]" ]]
    [[ $cb_count == 2 ]]
  done
}

function get_object_encode_examples() {
  example_names=(string number)
  format_names=(json attrs)
  examples+=(
    [json_string_in]=$'{"a b":"c d","e":"f"}\n{"":""}\n{"g":"h"}\n{}\n'
    [attrs_string_in]=$'a b=c d,e=f\n=\ng=h\n\n'
    [string_out]='"a b":"c d","e":"f","":"","g":"h"'

    [json_number_in]=$'{"a":1}\n{"b":2}\n{"c":3}\n'
    [attrs_number_in]=$'a=1\nb=2\nc=3\n'
    [number_out]=$'"a":1,"b":2,"c":3'
  )
}

@test "json.encode_from_file :: object" {
  local json_buffered_chunk_count=2 cb_count
  local tmp=$(mktemp_bats)  # can't use run because we need to see callbacks
  local example_names format_names; local -A examples; get_object_encode_examples

  for type in "${example_names[@]:?}"; do
  for format in "${format_names[@]:?}"; do
    # output to stdout
    cb_count=0
    collection=object split=$'\n' out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${format:?}_${type:?}_in"]}" ) > "${tmp:?}" 2>&1
    diff <(echo -n "{${examples[${type:?}_out]:?}}") "${tmp:?}"
    [[ $cb_count == 2 ]]

    # output to array
    buff=() cb_count=0
    out=buff collection=object split=$'\n' out_cb=_increment_cb_count \
      json.encode_from_file < <(echo -n "${examples["${format:?}_${type:?}_in"]}" )
    diff <(printf '%s' "${buff[@]}") <(echo -n "{${examples[${type:?}_out]:?}}")
    [[ $cb_count == 2 ]]
  done done
}

@test "json.stream_encode_array_entries :: stops reading file on error" {
  local json_buffered_chunk_count=2
  # We stop reading the stream if an element is invalid
  split=$'\n' type=number run json.stream_encode_array_entries \
    < <(seq 3; timeout 3 yes ) # stream a series of non-int values forever

  [[ $status == 1 && $output == \
    "1,2,json.encode_number(): not all inputs are numbers: '3' 'y'" ]]
}

@test "json.stream_encode_array_entries :: json_buffered_chunk_count=1 callback" {
  # json_buffered_chunk_count=1 results in readarray invoking the chunks
  # available callback with an empty array, which is a bit of an edge case.
  json_buffered_chunk_count=1 split=$'\n' type=string \
    run json.stream_encode_array_entries < <(printf '' )
  [[ $status == 0 && $output == '' ]]
  json_buffered_chunk_count=1 split=$'\n' type=string \
    run json.stream_encode_array_entries < <(printf 'foo\n' )
  [[ $status == 0 && $output == '"foo"' ]]
  json_buffered_chunk_count=1 split=$'\n' type=string \
    run json.stream_encode_array_entries < <(printf 'foo\nbar\n' )
  [[ $status == 0 && $output == '"foo","bar"' ]]
}

@test "json.stream_encode_array_entries" {
  local buff json_buffered_chunk_count=2
  local example_names; local -A examples; get_array_encode_examples
  for type in "${example_names[@]:?}"; do
    # Empty file
    split=$'\n' type=${type:?} run json.stream_encode_array_entries < <(echo -n '' )
    [[ $status == 0 && $output == "" ]]

    buff=() output=''
    out=buff split=$'\n' type=${type:?} json.stream_encode_array_entries < <(echo -n '' )
    printf -v output '%s' "${buff[@]}"
    [[ $status == 0 && $output == "" ]]

    # Non-empty file
    split=$'\n' type=${type:?} run json.stream_encode_array_entries \
      < <(echo -n "${examples["${type:?}_in"]}" )
    [[ $status == 0 && $output == "${examples[${type:?}_out]:?}" ]]

    buff=() output=''
    out=buff split=$'\n' type=${type:?} json.stream_encode_array_entries \
      < <(echo -n "${examples["${type:?}_in"]}" )
    printf -v output '%s' "${buff[@]}"
    [[ $status == 0 && $output == "${examples[${type:?}_out]:?}" ]]
  done

  # out_cb names a function that's called for each encoded chunk
  buff=()
  stdout_file=$(mktemp_bats)
  out=buff out_cb=__json.stream_encode_cb split=',' type=string \
    json.stream_encode_array_entries < <(printf 'a,b,c,d,e,f,g') > "${stdout_file:?}"

  # out_cb is called after each group of json_buffered_chunk_count chunks
  echo -n $'CB: "a","b"\nCB: "c","d"\nCB: "e","f"\nCB: "g"\n' | diff -u - "${stdout_file:?}"

  local expected=('"a","b"' ',' '"c","d"' ',' '"e","f"' ',' '"g"')
  assert_array_equals expected buff
}

@test "json.stream_encode_object_entries :: errors" {
  local buff json_buffered_chunk_count=2 expected=()

  # No format
  out=buff type=number split=$'\n' run json.stream_encode_object_entries \
    < <(printf '')
  [[ $status == 1 && $output == "json.stream_encode_object_entries: requested format does not exist — ''" ]]

  # Invalid format
  out=buff type=number split=$'\n' format=qwerty run json.stream_encode_object_entries \
    < <(printf '')
  [[ $status == 1 && $output == "json.stream_encode_object_entries: requested format does not exist — 'qwerty'" ]]

  # Invalid type
  out=buff type=qwerty split=$'\n' format=json run json.stream_encode_object_entries \
    < <(printf '{}')
  echo "${output:?}"
  [[ $status == 1 && $output == *"json.validate: unsupported \$type: 'qwerty_object'" ]]
}

@test "json.stream_encode_object_entries" {
  local buff json_buffered_chunk_count=2 expected=()

  # Empty input file
  buff=() expected=()
  out=buff type=number format=json split=$'\n' json.stream_encode_object_entries \
    < <(printf '')
  assert_array_equals buff expected

  out='' type=number format=json split=$'\n' run json.stream_encode_object_entries \
    < <(printf '')
  [[ $output == '' ]]

  # 4 input chunks, handling 2 chunks per callback
  buff=() expected=('"a":1,"b":2,"c":3,"d":4' ',' '"e":5,"e":6,"g":7,"h":8')
  out=buff type=number format=json split=$'\n' json.stream_encode_object_entries \
    <<<$'{"a":1,"b":2}\n{"c":3,"d":4}\n{"e":5,"e":6}\n{"g":7,"h":8}'
  assert_array_equals buff expected

  out='' type=number format=json split=$'\n' run json.stream_encode_object_entries \
    <<<$'{"a":1,"b":2}\n{"c":3,"d":4}\n{"e":5,"e":6}\n{"g":7,"h":8}'
  [[ $output == "$(printf '%s' "${expected[@]}")" ]]

  # 1 chunk per callback
  json_buffered_chunk_count=1
  buff=() expected=('"a":1,"b":2' ',' '"c":3,"d":4' ',' '"e":5,"e":6' ',' '"g":7,"h":8')
  out=buff type=number format=json split=$'\n' json.stream_encode_object_entries \
    <<<$'{"a":1,"b":2}\n{"c":3,"d":4}\n{"e":5,"e":6}\n{"g":7,"h":8}'
  assert_array_equals buff expected

  # default chunk counts
  json_buffered_chunk_count=''
  buff=() expected=('"a":1,"b":2,"c":3,"d":4,"e":5,"e":6,"g":7,"h":8')
  out=buff type=number format=json split=$'\n' json.stream_encode_object_entries \
    <<<$'{"a":1,"b":2}\n{"c":3,"d":4}\n{"e":5,"e":6}\n{"g":7,"h":8}'
  assert_array_equals buff expected
}

@test "json.stream_encode_object_entries :: attrs format" {
  local buff json_buffered_chunk_count=2
  buff=() expected=('"a":1,"b":2,"c":3,"d":4' ',' '"e":5,"f":6,"g":7,"h":8')
  out=buff type=number format=attrs split=$'\n' json.stream_encode_object_entries \
    <<<$'a=1,b=2\nc=3,d=4\ne=5,f=6\ng=7,h=8'
  assert_array_equals buff expected

  # When using null-terminated chunks, no split char is reserved, so 0x10 Data
  # Link Escape is chosen to be the character used to escape when parsing. 0x10
  # is escaped before parsing, so it should be able to occur as normal in inputs
  buff=() expected=('"foo\u0010bar":"x","a":"b\u0010\u0010c","\u0010=\u0010":"\u0010,\u0010"')
  out=buff type=string format=attrs split='' json.stream_encode_object_entries \
    < <(printf 'foo\x10bar=x,a=b\x10\x10c\x00'; printf '\x10==\x10=\x10,,\x10\x00')
  assert_array_equals buff expected
}

@test "json file input trailing newline handling" {
  local chunk lines expected
  # We mirror common shell behaviour of trimming newlines on input and creating
  # them on output.
  # e.g. command substitution trims newlines
  [[ $'foo\nbar' == "$(printf 'foo\nbar\n')" ]]
  # As does read (unless -N is used)
  read -r -d '' chunk < <(printf 'foo\nbar\n') || true
  [[ $'foo\nbar' == "$chunk" ]]
  # readarray preserves by default, but trims if -t is specified
  readarray -t chunk < <(printf 'foo\nbar\n')
  expected=(foo bar)
  assert_array_equals expected chunk
  # And word splitting
  lines=$'foo\nbar\n'
  chunk=($lines)
  assert_array_equals expected chunk

  # We trim whitespace when reading all types, except string and raw values.
  # e.g. json output is terminated by a newline
  diff <(json) <(printf '{}\n')
  # But the newline is trimed when inserting one json call into another:
  diff <(json a:json@<(json)) <(printf '{"a":{}}\n')
  # Notice that the shell's own command substitution does the same thing
  diff <(json a:json="$(json)") <(printf '{"a":{}}\n')
  # This behaviour means numbers parse from files without needing to explicitly
  # support trailing whitespace json.encode_number:
  diff <(json a:number="$(echo 1)" b:number@<(echo 2)) <(printf '{"a":1,"b":2}\n')
  # And similarly, arrays of numbers are trimmed of whitespace with the default
  # newline delimiter
  diff <(json a:number[]="$(seq 2)" b:number[]@<(seq 2)) <(printf '{"a":[1,2],"b":[1,2]}\n')

  # The first exception is string values, which preserve trailing newlines. This
  # is the default behaviour because a string exactly represents a text file's
  # contents, and newlines are significant content. If we trimmed them then
  # users would have no easy way to put them back. But users are able to trim
  # them themselves if they don't want them.
  diff <(json nl@<(printf 'foo\n')) <(printf '{"nl":"foo\\n"}\n')
  diff <(json no_nl@<(echo -n 'foo')) <(printf '{"no_nl":"foo"}\n')

  # The second execption is raw values. The raw type serves as an escape hatch,
  # passing JSON as-is, without validation, so it seems natural to not modify
  # their data by trimming newlines.
  diff <(json formatted:raw@<(printf '\n{\n  "msg": "hi"\n}\n')) \
       <(printf '{"formatted":\n{\n  "msg": "hi"\n}\n}\n')
  # Note that, when creating raw arrays with the (default) newline delmiter, the
  # delimiter is removed from the each value. This is the same as for arrays of
  # all types — the delimiter is not considered to be part of the value.
  diff <(json formatted:raw[]@<(printf '{}\n[]\n"hi"\n')) \
       <(printf '{"formatted":[{},[],"hi"]}\n')
  # Users can exercise precise control using null-terminated entries:
  diff -u <(json formatted:raw[]/split=/@<(printf '{\n}\n\n\x00[\n]\n\n\x00"hi"\n\n\x00')) \
       <(printf '{"formatted":[{\n}\n\n,[\n]\n\n,"hi"\n\n]}\n')
}

function assert_005_p1_match() {
  : ${arg?} ${splat?} ${flags?} ${value?} ${next?}

  [[ ${arg?} =~ $_json_bash_005_p1_key ]]
  local matched_splat=${BASH_REMATCH[1]} \
           matched_immediate_meta=${BASH_REMATCH[3]} \
           matched_key_flags=${BASH_REMATCH[4]} \
           matched_key_value=${BASH_REMATCH[5]}
  matched_next=${matched_immediate_meta?}${arg:${#BASH_REMATCH[0]}}

  # Move =/@ prefix to flags
  if [[ "${matched_key_value?}" == ['=@']* ]]; then
    matched_key_flags="${matched_key_flags?}${matched_key_value:0:1}"
    matched_key_value=${matched_key_value:1}
  fi

  diff -u <(printf '%s\n' "splat=${splat@Q}" "flags=${flags@Q}" \
                 "value=${value@Q}" "next=${next@Q}") \
          <(printf '%s\n' "splat=${matched_splat@Q}" "flags=${matched_key_flags@Q}" \
                          "value=${matched_key_value@Q}" "next=${matched_next@Q}") || {
    declare -p BASH_REMATCH
    return 1
  }
}

@test "json argument pattern 005 :: p1_key" {
  arg='' splat='' flags='' value='' next='' assert_005_p1_match
  arg=':string' splat='' flags='' value='' next=':string' assert_005_p1_match
  # Splat should be 3 '.' , but we want the match to always succeed so that we
  # have something to work with when reporting syntax errors.
  arg='.' splat='.' flags='' value='' next='' assert_005_p1_match
  arg='...' splat='...' flags='' value='' next='' assert_005_p1_match
  arg='.:' splat='.' flags='' value='' next=':' assert_005_p1_match
  arg='...:' splat='...' flags='' value='' next=':' assert_005_p1_match
  arg='....:' splat='....' flags='' value='' next=':' assert_005_p1_match

  # = escapes
  arg='=' splat='' flags='=' value='' next='' assert_005_p1_match
  arg='...=' splat='...' flags='=' value='' next='' assert_005_p1_match
  arg='==' splat='' flags='=' value='' next='=' assert_005_p1_match
  arg='...==' splat='...' flags='=' value='' next='=' assert_005_p1_match
  arg='===' splat='' flags='=' value='==' next='' assert_005_p1_match
  arg='====' splat='' flags='=' value='==' next='=' assert_005_p1_match
  arg='=====' splat='' flags='=' value='====' next='' assert_005_p1_match

  # : escapes
  arg='=::' splat='' flags='=' value='::' next='' assert_005_p1_match
  arg='=:::' splat='' flags='=' value='::' next=':' assert_005_p1_match
  arg='=::::' splat='' flags='=' value='::::' next='' assert_005_p1_match
  arg='@::' splat='' flags='@' value='::' next='' assert_005_p1_match
  arg='@:::' splat='' flags='@' value='::' next=':' assert_005_p1_match
  arg='@::::' splat='' flags='@' value='::::' next='' assert_005_p1_match
  arg='x::' splat='' flags='' value='x::' next='' assert_005_p1_match
  arg='x:::' splat='' flags='' value='x::' next=':' assert_005_p1_match
  arg='x::::' splat='' flags='' value='x::::' next='' assert_005_p1_match
  arg='~:' splat='' flags='~' value='' next=':' assert_005_p1_match
  arg='~::' splat='' flags='~' value='' next='::' assert_005_p1_match
  arg='~:::' splat='' flags='~' value='' next=':::' assert_005_p1_match

  arg='@' splat='' flags='@' value='' next='' assert_005_p1_match
  arg='...@' splat='...' flags='@' value='' next='' assert_005_p1_match
  arg='@@' splat='' flags='@' value='' next='@' assert_005_p1_match
  arg='...@@' splat='...' flags='@' value='' next='@' assert_005_p1_match
  arg='@@@' splat='' flags='@' value='@@' next='' assert_005_p1_match
  arg='@@@@' splat='' flags='@' value='@@' next='@' assert_005_p1_match
  arg='@@@@@' splat='' flags='@' value='@@@@' next='' assert_005_p1_match

  arg='~' splat='' flags='~' value='' next='' assert_005_p1_match
  arg='~?+' splat='' flags='~?+' value='' next='' assert_005_p1_match
  arg='~?+' splat='' flags='~?+' value='' next='' assert_005_p1_match
  arg='~=' splat='' flags='~=' value='' next='' assert_005_p1_match
  arg='~=:' splat='' flags='~=' value='' next=':' assert_005_p1_match
  arg='~@' splat='' flags='~@' value='' next='' assert_005_p1_match
  arg='~???+++~@' splat='' flags='~???+++~@' value='' next='' assert_005_p1_match
  arg='...~???+++~@' splat='...' flags='~???+++~@' value='' next='' assert_005_p1_match

  arg='foo' splat='' flags='' value='foo' next='' assert_005_p1_match
  arg='=foo' splat='' flags='=' value='foo' next='' assert_005_p1_match
  arg='@foo' splat='' flags='@' value='foo' next='' assert_005_p1_match
  arg='foo:' splat='' flags='' value='foo' next=':' assert_005_p1_match
  arg='foo=' splat='' flags='' value='foo' next='=' assert_005_p1_match
  arg='~foo=' splat='' flags='~' value='foo' next='=' assert_005_p1_match
  arg='~=foo=' splat='' flags='~=' value='foo' next='=' assert_005_p1_match
  arg='~@foo=' splat='' flags='~@' value='foo' next='=' assert_005_p1_match
}


function assert_005_p2_match() {
  if [[ ${match:-} == false ]]; then
    [[ ! ${arg?} =~ $_json_bash_005_p2_meta ]]
    return
  fi
  : ${arg?} ${type?} ${col?} ${split:=} ${fmt:=} ${attrs?} ${next?}

  [[ ${arg?} =~ $_json_bash_005_p2_meta ]]
  local -n matched_type=BASH_REMATCH[1] \
           matched_col=BASH_REMATCH[2] \
           matched_split=BASH_REMATCH[3] \
           matched_fmt=BASH_REMATCH[4] \
           matched_attrs=BASH_REMATCH[5]
  matched_next=${arg:${#BASH_REMATCH[0]}}

  diff -u <(printf '%s\n' "type=${type@Q}" "collection=${col@Q}" \
                          "split=${split@Q}" "fmt=${fmt@Q}" \
                          "attributes=${attrs@Q}" "next=${next@Q}") \
          <(printf '%s\n' "type=${matched_type@Q}" "collection=${matched_col@Q}" \
                          "split=${matched_split@Q}" "fmt=${matched_fmt@Q}" \
                          "attributes=${matched_attrs@Q}" "next=${matched_next@Q}") || {
    declare -p BASH_REMATCH
    return 1
  }
}

@test "json argument pattern 005 :: p2_meta" {
  arg=':' type='' col='' attrs='' next='' assert_005_p2_match
  arg=':string' type='string' col='' attrs='' next='' assert_005_p2_match
  arg=':String' type='String' col='' attrs='' next='' assert_005_p2_match
  arg=':str8n' type='str8n' col='' attrs='' next='' assert_005_p2_match
  arg=':[]' type='' col='[]' attrs='' next='' assert_005_p2_match
  arg=':[,]' type='' col='[,]' split=',' attrs='' next='' assert_005_p2_match
  arg=':{}' type='' col='{}' attrs='' next='' assert_005_p2_match
  arg=':{,}' type='' col='{,}' split=',' attrs='' next='' assert_005_p2_match
  arg=':{,:json}' type='' col='{,:json}' split=',' fmt=':json' attrs='' next='' assert_005_p2_match
  arg=':{:foo_123}' type='' col='{:foo_123}' fmt=':foo_123' attrs='' next='' assert_005_p2_match
  # The regex allows mismatched endings, but they get caught when parsing
  arg=':[,:foo_123}' type='' col='[,:foo_123}' split=',' fmt=':foo_123' attrs='' next='' assert_005_p2_match
  arg='://' type='' col='' attrs='//' next='' assert_005_p2_match
  arg=':/abc/' type='' col='' attrs='/abc/' next='' assert_005_p2_match

  arg=':foo[/]/abc/' type='foo' col='[/]' split='/' attrs='/abc/' next='' assert_005_p2_match
  arg=':foo[]]/abc/' type='foo' col='[]]' split=']' attrs='/abc/' next='' assert_005_p2_match
  arg=':foo{/}/abc/' type='foo' col='{/}' split='/' attrs='/abc/' next='' assert_005_p2_match
  arg=':foo{}}/abc/' type='foo' col='{}}' split='}' attrs='/abc/' next='' assert_005_p2_match

  arg=':=abc' type='' col='' attrs=''  next='=abc' assert_005_p2_match
  arg=':foo[]/abc/=abc' type='foo' col='[]' attrs='/abc/'  next='=abc' assert_005_p2_match

  arg='' match=false assert_005_p2_match
  arg=' :string' match=false assert_005_p2_match
  arg='foo' match=false assert_005_p2_match
  arg='=blah' match=false assert_005_p2_match
  arg=':]]' type='' col='' attrs='' next=']]' assert_005_p2_match
  arg=':}}' type='' col='' attrs='' next='}}' assert_005_p2_match
  arg=':/foo/[]' type='' col='' attrs='/foo/' next='[]' assert_005_p2_match
  arg=':/foo/{}' type='' col='' attrs='/foo/' next='{}' assert_005_p2_match
}

function assert_005_p3_match() {
  if [[ ${match:-} == false ]]; then
    [[ ! ${arg?} =~ $_json_bash_005_p3_value ]]
    return
  fi
  : ${arg?} ${flags?} ${next?}

  [[ ${arg?} =~ $_json_bash_005_p3_value ]]
  local -n matched_flags=BASH_REMATCH[0]
  matched_next=${arg:${#BASH_REMATCH[0]}}

  declare -p BASH_REMATCH
  diff -u <(printf '%s\n' "flags=${flags@Q}" "next=${next@Q}") \
          <(printf '%s\n' "flags=${matched_flags@Q}" "next=${matched_next@Q}") || {
    declare -p BASH_REMATCH
    return 1
  }
}

@test "json argument pattern 005 :: p3_value" {
  arg='' flags='' next='' assert_005_p3_match
  arg='blah' flags='' next='blah' assert_005_p3_match
  arg='??' flags='??' next='' assert_005_p3_match
  arg='??sdfs' flags='??' next='sdfs' assert_005_p3_match
  arg='=' flags='=' next='' assert_005_p3_match
  arg='@' flags='@' next='' assert_005_p3_match
  arg='=foo' flags='=' next='foo' assert_005_p3_match
  arg='@foo' flags='@' next='foo' assert_005_p3_match
  arg='?+~=foo' flags='?+~=' next='foo' assert_005_p3_match
  arg='?+~@foo' flags='?+~@' next='foo' assert_005_p3_match
}

function assert_arg_parse2_invalid_argument() {
  : ${arg?} ${msg:?}
  out=__ignored run json._parse_argument2 "${arg?}"

  [[ $status == 1 ]] \
    || { echo "arg unexpectedly parsed successfully: ${arg@Q}" >&2; return 1; }
  [[ $output = *$msg* ]] || {
    echo "output did not contain msg: msg=${msg@Q}," \
      "output=${output@Q}" >&2; return 1;
  }
}

@test "json._parse_argument2 :: reports invalid arguments" {
  arg='.' msg="splat operator must be '...'" assert_arg_parse2_invalid_argument
  arg='....' msg="splat operator must be '...'" assert_arg_parse2_invalid_argument
  arg=':cheese' msg="type name must be one of auto, bool, false, json, null, number, raw, string or true, but was 'cheese'" assert_arg_parse2_invalid_argument

  arg=':[' msg="The argument is not correctly structured:" assert_arg_parse2_invalid_argument
  arg=':{' msg="The argument is not correctly structured:" assert_arg_parse2_invalid_argument
  arg=':[}' msg="collection marker is not structured correctly — '[}'" assert_arg_parse2_invalid_argument
  arg=':/foo=//=abc' msg="The argument is not correctly structured:" assert_arg_parse2_invalid_argument
  arg='://foo' msg="The argument is not correctly structured:" assert_arg_parse2_invalid_argument
}

function assert_arg_parse2() {
  expected=$(timeout 1 cat)
  expected=${expected/#+([ $'\n'])/}
  expected=${expected/%+([ $'\n'])/}
  local -A attrs
  out=attrs json._parse_argument2 "$1" || return 10
  local attr_lines=() line
  for name in "${!attrs[@]}"; do
    printf -v line "%s = '%s'" "$name" "${attrs[$name]}"
    attr_lines+=("${line:?}")
  done
  sorted_attrs=$(local IFS=$'\n'; LC_ALL=C sort <<<"${attr_lines[*]}")
  if [[ $expected != "${sorted_attrs}" ]]; then
    diff -u <(echo "${expected:?}") <(echo "${sorted_attrs}")
    return 1
  fi
}

@test "json._parse_argument2 :: parses valid arguments" {
  assert_arg_parse2 '' <<<""  # no attrs
  assert_arg_parse2 : <<<""
  # keys
  assert_arg_parse2 ... <<<"
splat = 'true'
"
  assert_arg_parse2 ...: <<<"
splat = 'true'
"
  assert_arg_parse2 foo <<<"
@key = 'str'
key = 'foo'
"
  assert_arg_parse2 ++~~???foo <<<"
@key = 'str'
key = 'foo'
key_flag_empty = '??'
key_flag_no = '~'
key_flag_strict = '+'
"
  # We're not strict about flag order or count - more than the required number
  # are the same as the same as the max.
  assert_arg_parse2 ++~~???=foo <<<"
@key = 'str'
key = 'foo'
key_flag_empty = '??'
key_flag_no = '~'
key_flag_strict = '+'
"
  assert_arg_parse2 ++~~???@foo <<<"
@key = 'var'
key = 'foo'
key_flag_empty = '??'
key_flag_no = '~'
key_flag_strict = '+'
"
  assert_arg_parse2 ++~~???@/file <<<"
@key = 'file'
key = '/file'
key_flag_empty = '??'
key_flag_no = '~'
key_flag_strict = '+'
"
  assert_arg_parse2 ++~~???@./file <<<"
@key = 'file'
key = './file'
key_flag_empty = '??'
key_flag_no = '~'
key_flag_strict = '+'
"
  assert_arg_parse2 ?=foo~~++???= <<<"
@key = 'str'
@val = 'str'
key = 'foo'
key_flag_empty = '?'
val = ''
val_flag_empty = '??'
val_flag_no = '~'
val_flag_strict = '+'
"
  assert_arg_parse2 = <<<"
@key = 'str'
key = ''
"
  assert_arg_parse2 == <<<"
@key = 'str'
@val = 'str'
key = ''
val = ''
"
  assert_arg_parse2 === <<<"
@key = 'str'
key = '='
"
  assert_arg_parse2 ===? <<<"
@key = 'str'
key = '='
val_flag_empty = '?'
"
  assert_arg_parse2 @ <<<"
@key = 'var'
key = ''
"
  assert_arg_parse2 @@ <<<"
@key = 'var'
@val = 'var'
key = ''
val = ''
"
  assert_arg_parse2 @@@ <<<"
@key = 'var'
key = '@'
"
  assert_arg_parse2 @@@? <<<"
@key = 'var'
key = '@'
val_flag_empty = '?'
"
  assert_arg_parse2 :string <<<"
type = 'string'
"
  assert_arg_parse2 :[] <<<"
collection = 'array'
"
  assert_arg_parse2 :[,] <<<"
collection = 'array'
split = ','
"
  assert_arg_parse2 :{} <<<"
collection = 'object'
"
  # , inside {} needs quoting (at the bash level) to avoid expansion as two empty alternatives
  assert_arg_parse2 :'{,}' <<<"
collection = 'object'
split = ','
"
  # others don't though
  assert_arg_parse2 :{:} <<<"
collection = 'object'
split = ':'
"
  # object arguments can specify an input chunk format
  assert_arg_parse2 :{::json} <<<"
collection = 'object'
format = 'json'
split = ':'
"
  assert_arg_parse2 :{:attrs} <<<"
collection = 'object'
format = 'attrs'
"
  assert_arg_parse2 :// <<<""
  assert_arg_parse2 :/a=b,,c,d===e==f,==g=//h/ <<<"
=g = '/h'
a = 'b,c'
d= = 'e==f'
"
  assert_arg_parse2 :++~~??? <<<"
val_flag_empty = '??'
val_flag_no = '~'
val_flag_strict = '+'
"
  assert_arg_parse2 := <<<"
@val = 'str'
val = ''
"
  assert_arg_parse2 :=x <<<"
@val = 'str'
val = 'x'
"
  assert_arg_parse2 :=foobar <<<"
@val = 'str'
val = 'foobar'
"
  assert_arg_parse2 :@foobar <<<"
@val = 'var'
val = 'foobar'
"
  assert_arg_parse2 :@/file <<<"
@val = 'file'
val = '/file'
"
  assert_arg_parse2 :@./file <<<"
@val = 'file'
val = './file'
"
  assert_arg_parse2 '...++~~???=tobe?:string{,:json}/a=b/++~~???@./or/not' <<<"
@key = 'str'
@val = 'file'
a = 'b'
collection = 'object'
format = 'json'
key = 'tobe?'
key_flag_empty = '??'
key_flag_no = '~'
key_flag_strict = '+'
splat = 'true'
split = ','
type = 'string'
val = './or/not'
val_flag_empty = '??'
val_flag_no = '~'
val_flag_strict = '+'
"
}

@test "json.parse_attributes" {
  local -A attrs expected
  local keys values ex_keys ex_values src

  attrs=(); out=attrs json.parse_attributes ''
  keys=() values=(); out=keys,values json.parse_attributes ''
  expected=(); assert_array_equals attrs expected
  ex_keys=(); assert_array_equals keys ex_keys
  ex_values=(); assert_array_equals values ex_values


  attrs=(); out=attrs json.parse_attributes 'a=b,c=d'
  keys=() values=(); out=keys,values json.parse_attributes 'a=b,c=d'
  expected=([a]=b [c]=d); assert_array_equals attrs expected
  ex_keys=(a c); assert_array_equals keys ex_keys
  ex_values=(b d); assert_array_equals values ex_values


  attrs=(); out=attrs json.parse_attributes 'ab=c//d,e=f,,g'
  keys=() values=(); out=keys,values json.parse_attributes 'ab=c//d,e=f,,g'
  expected=(['ab']='c/d' ['e']='f,g'); assert_array_equals attrs expected
  ex_keys=(ab e); assert_array_equals keys ex_keys
  ex_values=(c/d f,g); assert_array_equals values ex_values


  attrs=(); out=attrs json.parse_attributes 'a==b=c,d===e,===f'
  keys=() values=(); out=keys,values json.parse_attributes 'a==b=c,d===e,===f'
  expected=(['a=b']='c' ['d=']='e' ['=']='f'); assert_array_equals attrs expected
  ex_keys=(a=b d= =); assert_array_equals keys ex_keys
  ex_values=(c e f); assert_array_equals values ex_values

  # multiple input chunks with empty chunks (that are ignored)
  attrs=(); out=attrs json.parse_attributes '' 'a=1,b=2' '' 'c=3,d=4' ''
  keys=() values=(); out=keys,values json.parse_attributes '' 'a=1,b=2' '' 'c=3,d=4' ''
  expected=(['a']='1' ['b']='2' ['c']='3' ['d']='4'); assert_array_equals attrs expected
  ex_keys=(a b c d); assert_array_equals keys ex_keys
  ex_values=(1 2 3 4); assert_array_equals values ex_values

  # Input from array
  src=('' 'a=1,b=2' '' 'c=3,d=4' '')
  attrs=(); out=attrs in=src json.parse_attributes
  keys=() values=(); out=keys,values in=src json.parse_attributes
  expected=(['a']='1' ['b']='2' ['c']='3' ['d']='4'); assert_array_equals attrs expected
  ex_keys=(a b c d); assert_array_equals keys ex_keys
  ex_values=(1 2 3 4); assert_array_equals values ex_values

  # Alternate reserved char
  # / is reserved by default as it's reserved when parsing attrs from arguments.
  # But we can use a different char if we know it won't occur. e.g. if chunks
  # were split on newlines, that must not occur. This char is used internally
  # to escape = and , when parsing.
  keys=() values=(); out=keys,values reserved=! json.parse_attributes \
    'a!!b==c=1!!2,,3,d=4' 'e,,f==g!!h=5,i=6'
  declare -p keys values ex_keys ex_values
  ex_keys=('a!b=c' 'd' 'e,f=g!h' 'i'); assert_array_equals keys ex_keys
  ex_values=('1!2,3' '4' '5' '6'); assert_array_equals values ex_values
}

# Assert JSON on stdin matches JSON given as the first argument.
function equals_json() {
  if (( $# != 1 )); then
    echo "equals_json: usage: echo '{...}' | equals_json '{...}'" >&2; return 1
  fi

  actual=$(timeout 1 cat) \
    || { echo "equals_json: failed to read stdin" >&2; return 1; }
  expected=$(jq -cne "${1:?}") \
    || { echo "equals_json: jq failed to evalute expected JSON" >&2; return 1; }

  if ! python3 -m json.tool <<<"${actual}" > /dev/null; then
    echo "equals_json: json function output is not valid JSON: '$actual'" >&2; return 1
  fi

  eq=false
  if [[ ${compare:-serialised} == serialised ]]; then
    [[ ${expected:?} == "${actual}" ]] && eq=true
  elif [[ ${compare:-} == parsed ]]; then
    jq -ne --argjson x "${expected:?}" --argjson y "${actual:?}" '$x == $y' > /dev/null \
      && eq=true
  else
    echo "equals_json: Unknown compare value: '${compare:-}'" >&2; return 1;
  fi

  if [[ $eq != true ]]; then
    echo "equals_json: json output did not match expected:
expected: $expected
  actual: $actual" >&2
    expected_f=$(mktemp --suffix=.json.bats.expected)
    actual_f=$(mktemp --suffix=.json.bats.actual)
    python3 -m json.tool <<<"${expected}" > "${expected_f:?}"
    python3 -m json.tool <<<"${actual}" > "${actual_f:?}"
    diff -u "${expected_f:?}" "${actual_f:?}" >&2
    return 1
  fi
}

@test "json.bash json / json.array / json.object functions" {
  # The json function creates JSON objects
  json | equals_json '{}'
  # It creates arrays if json_return=array
  json_return=array json | equals_json '[]'
  # json.array is the same as json with json_return=array set
  json.array | equals_json '[]'
  # json.object is also defined, for consistency
  json.object | equals_json '{}'
}

@test "json.bash json keys" {
  # Keys
  json msg=hi | equals_json '{msg: "hi"}'
  # Keys can contain most characters (except @:=)
  json "🦬 says"=hi | equals_json '{"🦬 says": "hi"}'
  # Key values can come from variables
  key="The Message" json @key=hi | equals_json '{"The Message": "hi"}'
  # Key vars can contain any characters
  key="@key:with=reserved-chars" json @key=hi \
    | equals_json '{"@key:with=reserved-chars": "hi"}'
  # Each argument defines a key
  var=c json a=X b=Y @var=Z | equals_json '{a: "X", b: "Y", c: "Z"}'
  # Keys may be reused, but should not be, because JSON parser behaviour for
  # duplicate keys is undefined.
  [[ $(json a=A a=B a=C) == '{"a":"A","a":"B","a":"C"}' ]]
  json a=A a=B a=C | compare=parsed equals_json '{a: "C"}'

  # References can point to array indexes and other namerefs
  local -A paths=([ls]=/bin/ls [cat]=/bin/cat); local progs=(ls cat)
  local -n catref=paths[cat]
  json @paths[ls]=ls_path @progs[1]=prog2 @catref=ref \
    | equals_json '{"/bin/ls": "ls_path", "cat": "prog2", "/bin/cat": "ref"}'
}

@test "json.bash json — objects with fixed keys" {
  # Property values can be set in the argument
  json message="Hello World" | equals_json '{message: "Hello World"}'
  # Or with a variable
  greeting="Hi there" json message@greeting \
    | equals_json '{message: "Hi there"}'
  # Variable references without a value are used as the key and value
  greeting="Hi" name=Bob json @greeting @name \
    | equals_json '{greeting: "Hi", name: "Bob"}'
  # This also works (less usefully) for inline entries
  json message | equals_json '{message: "message"}'
  # There are no restrictions on values following a =
  json message=@value:with=reserved-chars \
    | equals_json '{message: "@value:with=reserved-chars"}'

  # References can point to array indexes and other namerefs
  local -A paths=([ls]=/bin/ls [cat]=/bin/cat); local progs=(ls cat)
  local -n catref=paths[cat]
  json ls_path@paths[ls] prog2@progs[1] ref@catref \
    | equals_json '{ls_path: "/bin/ls", prog2: "cat", ref: "/bin/cat"}'
}

@test "json.bash json.array — arrays with fixed values" {
  # Array values can also be set in the arguments
  json.array Hi "Bob Bobson" | equals_json '["Hi", "Bob Bobson"]'
  # Or via variables
  message=Hi name="Bob Bobson" json.array @message @name \
    | equals_json '["Hi", "Bob Bobson"]'
  # Array values in arguments cannot contain @:= characters, because they would
  # clash with @variable and :type syntax. However, values following a := can
  # contain anything
  json.array :='@foo:bar=baz' :='{"not":"parsed"}' \
    | equals_json '["@foo:bar=baz", "{\"not\":\"parsed\"}"]'
  # Values from variables have no restrictions. Arrays use the same argument
  # syntax as objects, so values in the key or value position work the same.
   s1='@foo:bar=baz' s2='{"not":"parsed"}' json.array @s1 @s2 \
    | equals_json '["@foo:bar=baz", "{\"not\":\"parsed\"}"]'
  # It's possible to set a key as well as value for array entries, but the key
  # is ignored.
  a=A b=B json.array @a@a @b=B c=C | equals_json '["A", "B", "C"]'
}

@test "json.bash json :: types" {
  # Types
  # Values are strings by default
  json data=42 | equals_json '{data: "42"}'
  # Non-string values need explicit types
  json data:number=42 | equals_json '{data: 42}'
  # true/false/null have types which don't require redundant values
  json active:true enabled:false data:null \
    | equals_json '{active: true, enabled: false, data: null}'
  # Regardless, they can be given values if desired
  json active:true=true enabled:false=false data:null=null \
    | equals_json '{active: true, enabled: false, data: null}'
  # The bool type allows either true or false values.
  active=true json @active:bool enabled:bool=false \
    | equals_json '{active: true, enabled: false}'
  # The auto type outputs true/false/null and number values. You can opt into
  # this globally by exporting json_type=auto as an environment variable.
  # JSON object and array values are not parsed with auto, only simple values.
  json.define_defaults autos type=auto
  json_defaults=autos json a=42 b="Hi" c=true d=false e=null f=[] g={} \
    | equals_json '{a: 42, b: "Hi", c: true, d: false, e: null,
                    f: "[]", g: "{}"}'
  # auto can be used selectively like other types
  data=42 json a=42 b:auto=42 c:auto@data \
    | equals_json '{a: "42", b: 42, c: 42}'
}

@test "json.bash json :: variable-length array values" {
  # Arrays of values can be created using the [] suffix with each type
  json sizes:number[]=42 | equals_json '{sizes: [42]}'

  # The value is split on the character inside the []
  json names:[:]="Alice:Bob:Dr Chris" \
    | equals_json '{names: ["Alice", "Bob", "Dr Chris"]}'

  # The default split character is line feed (\n), so each line is an array
  # element. This integrates with line-oriented command-line tools:
  json sizes:[]="$(seq 3)" | equals_json '{sizes: ["1","2","3"]}'
  json sizes:number[]="$(seq 3)" | equals_json '{sizes: [1, 2, 3]}'

  # The same applies when reading arrays from files
  # (Note that <(seq 3) is a shell construct (process substitution) that prints
  # the path to a file containing the output of the `seq 3` command (1 2 3 on
  # separate lines.)
  json sizes:number[]@<(seq 3) | equals_json '{sizes: [1, 2, 3]}'

  # [:] is shorthand for [split=:]
  json names:[]/split=:/="Alice:Bob:Dr Chris" \
    | equals_json '{names: ["Alice", "Bob", "Dr Chris"]}'
  # The last split value wins when used more than once
  json sizes:number[:]/split=!,split=///=1/2/3 | equals_json '{sizes: [1, 2, 3]}'

  # To split on null bytes, use split= (empty string). When used with inline and
  # bash values this effectively inhibits splitting, because bash variables
  # can't contain null bytes.
  printf 'AB\nCD\x00EF\nGH\n\x00' | json nullterm:[]/split=/@/dev/stdin \
    | equals_json '{nullterm: ["AB\nCD", "EF\nGH\n"]}'

  # @var references can be bash arrays
  local names=("Bob Bobson" "Alice Alison")
  sizes=(42 55)
  json @names:string[] @sizes:number[] | equals_json '{
    names: ["Bob Bobson", "Alice Alison"],
    sizes: [42, 55]
  }'
  # json.array values can be arrays too
  json.array @names:string[] @sizes:number[] :null[] :bool[]=true | equals_json '[
    ["Bob Bobson", "Alice Alison"],
    [42, 55],
    [null],
    [true]
  ]'
  # empty inline values are empty arrays
  json str:string[]= num:number[]= bool:bool[]= raw:raw[]= json:json[]= \
    | equals_json '{str: [], num: [], bool: [], raw: [], json: []}'

  # array variables can be empty, both via empty arrays and an empty string
  local nothing=() empty=''
  json @nothing:[] @empty:[] | equals_json '{nothing: [], empty: []}'
}

@test "json.bash json :: variable-length object values" {
  # An argument using {} creates an object with values of the specified type
  # Bash associative array variables can hold entries
  local -A sizes=(['xs']=0 ['s']=10 ['m']=20 ['l']=30 ['xl']=40)
  json @sizes:number{} \
    | compare=parsed equals_json '{sizes: {xs: 0, s: 10, m: 20, l: 30, xl: 40}}'

  # Inline argument values use the same key=value syntax as argument attributes
  json sizes:number{}=xs=0,s=10,m=20,l=30,xl=40 \
    | compare=parsed equals_json '{sizes: {xs: 0, s: 10, m: 20, l: 30, xl: 40}}'

  # File references merge JSON objects from each line of the file
  json.define_defaults number type=number
  local json_defaults=number
  json sizes:number{}@<(
    json xs=0 s=10
    json m=20 l=30
    json xl=40
  ) | compare=parsed equals_json '{sizes: {xs: 0, s: 10, m: 20, l: 30, xl: 40}}'

  # Bash indexed arrays also merge JSON objects from each array element
  unset sizes; local -a sizes=()
  out=sizes json xs=0 s=10
  out=sizes json m=20 l=30
  out=sizes json xl=40
  json @sizes:number{} | equals_json '{sizes: {xs: 0, s: 10, m: 20, l: 30, xl: 40}}'

  unset json_defaults

  # The format of arguments can be changed using :json or :attrs inside the {}
  json fromjson:{:json}='{"foo":"bar"}' fromattrs:{:attrs}@<(echo 'bar=baz') \
    | equals_json '{"fromjson":{"foo":"bar"},"fromattrs":{"bar":"baz"}}'

  find bin -type f -exec wc -w {} + | head -n-1 | awk '{ print $2"="$1 }' \
    | json files:number{:attrs}@/dev/stdin \
    | equals_json '{"files":{"bin/jb-cat":260,"bin/jb-echo":85,"bin/jb-stream":167}}'
}

@test "json.bash json.define_defaults :: returns 2 if type is invalid" {
  run json.define_defaults example type=cheese
  [[ $status == 2 \
    && $output =~ "json.define_defaults(): defaults contain invalid 'type': 'cheese'" ]]
}

@test "json.bash json :: uses default type from json_defaults" {
  # The default string type can be changed with json_defaults
  json.define_defaults numeric type=number
  json_defaults=numeric json data=42 | equals_json '{data: 42}'
  # In which case strings need to be explicitly typed
  json_defaults=numeric json data=42 msg:string=Hi \
    | equals_json '{data: 42, msg: "Hi"}'
}

@test "json.bash json :: uses default collection flag from json_defaults" {
  # The default array=true/false flag can be changed with json_defaults
  json.define_defaults arrays collection=array
  json_defaults=arrays json data=42 | equals_json '{data: ["42"]}'
  # array can be disabled with an explicit attribute
  json_defaults=arrays json data=42 msg:[]/collection=false/=Hi \
    | equals_json '{data: ["42"], msg: "Hi"}'
}

@test "json.bash json.define_defaults :: allows defaults to be re-defined" {
  json.define_defaults example type=number
  json_defaults=example json a=42 | equals_json '{a:42}'
  json.define_defaults example type=auto,collection=array
  json_defaults=example json a=42 b=hi | equals_json '{a:[42],b:["hi"]}'
}

@test "json.bash json nested JSON with :json and :raw types" {
  # Nested objects and arrays are created using the json or raw types. The :raw
  # type allow any value to be inserted (even invalid JSON), whereas :json
  # validates the provided value(s) and fails if they're not actually JSON.
  #
  # The reason for both is that :json depends on grep (with PCRE) being present,
  # so :raw can be used in situations where only bash is available, and
  # validation isn't necessary (e.g. when passing the output of one json.bash
  # call into another).

  for type in json raw; do
    json user:$type='{"name":"Bob Bobson"}' \
      | equals_json '{user: {name: "Bob Bobson"}}'

    user='{"name":"Bob Bobson"}' json @user:$type \
      | equals_json '{user: {name: "Bob Bobson"}}'

    user='{"name":"Bob Bobson"}' json "User":$type@user \
      | equals_json '{User: {name: "Bob Bobson"}}'

    # Use nested json calls to create nested JSON objects or arrays
    json user:$type="$(json name="Bob Bobson")" \
      | equals_json '{user: {name: "Bob Bobson"}}'

    # Variables can hold JSON values to incrementally build larger objects.
    local people=()
    out=people json name="Bob" pet="Tiddles"
    out=people json name="Alice" pet="Frankie"
    json type=people status:$type="$(json created_date=yesterday final:false)" \
      users:$type[]@people \
      | equals_json '{
          type: "people", status: {created_date: "yesterday", final: false},
          users: [
            {name: "Bob", pet: "Tiddles"},
            {name: "Alice", pet: "Frankie"}
          ]
        }'
  done
}

@test "json.bash file references" {
  tmp=$(mktemp_bats -d); cd "${tmp:?}"
  printf 'orange #3\nblue #5\n' > colours

  # The @... syntax can be used to reference the content of files. If an @ref
  # starts with / or ./ it's taken to be a file.
  json my_colours@./colours | equals_json '{my_colours: "orange #3\nblue #5\n"}'
  # The final path segment is used as the key if a key isn't set.
  json @./colours | equals_json '{colours: "orange #3\nblue #5\n"}'
  # Array values split on newlines
  json @./colours:[] | equals_json '{colours: ["orange #3", "blue #5"]}'

  printf 'apple,pear,grape' > fruit
  # The file can be split on a different character by naming it in the []
  json @./fruit:[,] | equals_json '{fruit: ["apple", "pear", "grape"]}'
  # , needs escaping by doubling inside the attributes section
  json @./fruit:[]/split=,,/ | equals_json '{fruit: ["apple", "pear", "grape"]}'

  # Split on null by setting split to the empty string
  printf 'foo\nbar\n\x00bar baz\n\x00' > nullterminated
  json @./nullterminated:[]/split=/ \
    | equals_json '{nullterminated: ["foo\nbar\n", "bar baz\n"]}'

  # Read from stdin using the special /dev/stdin file
  seq 3 | json counts:number[]@/dev/stdin | equals_json '{counts:[1, 2, 3]}'

  # Use process substitution to nest json calls and consume multiple streams.
  json counts:number[]@<(seq 3) \
       people:json[]@<(json name=Bob; json name=Alice) \
    | equals_json '{counts:[1, 2, 3], people: [{name: "Bob"},{name: "Alice"}]}'
  #   Aside: if you're not clear on what's happening here, try $ cat <(seq 3)
  #   and also $ echo <(seq 3)

  # Files can be referenced indirectly using a variable.
  # If @var is used and $var is not set, but $var_FILE is, the filename is read
  # from $var_FILE and the content of the file is used.
  printf 'secret123' > db_password
  db_password_FILE=./db_password json @db_password \
    | equals_json '{db_password: "secret123"}'
  # (This pattern is commonly used to pass secrets securely via environment
  # variables.)

  # Property names can come from files
  json @<(printf prop_name)=value | equals_json '{prop_name: "value"}'
}

@test "json.bash json errors :: do not produce partial JSON output" {
  # No partial output on errors — either json suceeds with output, or fails with
  # no output.
  run json foo=bar error:number=notanumber
  [[ $status == 1 ]]
  # no JSON in output:
  [[ ! $output =~ '{' ]]
  echo "${output@Q}"
  [[ "$output" == *"failed to encode value as number: 'notanumber' from 'error:number=notanumber'"* ]]

  # Same for array output
  local buff=() err=$(mktemp_bats)
  # Can't use run because it forks, and the fork can't write to our buff
  out=buff json ok:true
  out=buff json foo=bar error:number=notanumber 2> "${err:?}" || status=$?
  out=buff json garbage:false

  [[ ${status:-} == 1 ]]
  [[ ! $(cat "${err:?}") =~ '{' ]]
  [[ $(cat "${err:?}") == \
    *"failed to encode value as number: 'notanumber' from 'error:number=notanumber'"* ]]
  declare -p buff
  [[ ${#buff[@]} == 3 && ${buff[0]} == '{"ok":true}' \
    && ${buff[1]} == $'\x18' && ${buff[2]} == '{"garbage":false}' ]]
}

@test "json.bash json option handling" {
  # Keys can start with -. This will conflict with command-line arguments if we
  # were to support them.
  json -a=b | equals_json '{"-a": "b"}'
  # But we support the common idiom of using a -- argument to disambiguate
  # options from arguments, so if we add options then this can be used to
  # future-proof handling of hyphen-prefixed arguments.
  # Note that the first -- is ignored, but the second is not ignored.
  json a=x -- -a=y -- --a=z | equals_json '{a:"x","-a":"y","--":"--","--a":"z"}'
}

@test "json.bash json non-simple arguments are handled by full parser" {
  json =@@foo=x | equals_json '{"@foo":"x"}'
  json === | equals_json '{"=":"="}'  # key is = but key gets re-used as value
  json ==== | equals_json '{"=":""}'
  json ====x | equals_json '{"=":"x"}'
  json ===x= | equals_json '{"=x":""}'
  json a[b=x | equals_json '{"a[b":"x"}'
  json a::b=x | equals_json '{"a:b":"x"}'
}

@test "json.bash json errors" {
  # inline keys can't contain : (basically parsed as an invalid type)
  run json a:b:string
  echo "$status"
  echo "$output"
  [[ $status == 2 && $output =~ "type name must be one of auto, bool, false, json, null, number, raw, string or true, but was 'b'" ]]

  # invalid types are not allowed
  run json :cheese[]
  [[ $status == 2 && $output =~ "type name must be one of auto, bool, false, json, null, number, raw, string or true, but was 'cheese'" ]]

  # A json_defaults value that is not a name that has been defined with
  # json.define_defaults is an error.
  json_defaults=__undefined__ run json
  [[ $status == 2 && $output =~ "json(): json.define_defaults has not been called for json_defaults value: '__undefined__'" ]]

  # Empty raw values are errors
  run json a:raw=
  [[ $status == 1 && $output =~ "raw JSON value is empty" ]]

  # Invalid typed values are errors
  run json a:number=a
  [[ $status == 1 && $output =~ "failed to encode value as number: 'a' from 'a:number=a'" ]]
  run json a:number[]=a
  [[ $status == 1 && $output =~ "failed to encode value as number: 'a' from 'a:number[]=a'" ]]
  run json a:bool=a
  [[ $status == 1 && $output =~ "failed to encode value as bool: 'a' from 'a:bool=a'" ]]
  run json a:null=a
  [[ $status == 1 && $output =~ "failed to encode value as null: 'a' from 'a:null=a'" ]]

  # Syntax errors in :json type values are errors
  run json a:json=
  [[ $status == 1 && $output =~ "failed to encode value as json: '' from 'a:json='" \
    && $output =~ "json.encode_json(): not all inputs are valid JSON: ''" ]]

  run json a:json='{"foo":'
  [[ $status == 1 \
    && $output =~ " failed to encode value as json: '{\"foo\":' from 'a:json={\"foo\":'" ]]

  local json_things=('true' '["invalid"')
  run json a:json[]@json_things
  [[ $status == 1 \
    && $output =~ "failed to encode value as json: 'true' '[\"invalid\"' from 'a:json[]@json_things'" ]]

  # references to missing variables are errors
  run json @__missing
  [[ $status == 3 && $output =~ \
    "argument references unbound variable: \$__missing from '@__missing" ]]

  missing_file=$(mktemp_bats --dry-run)
  # references to missing files are errors
  # ... when used as keys
  run json @${missing_file:?}=value
  [[ $status == 4 && $output =~ \
    "json(): failed to read file referenced by argument: '${missing_file:?}' from '@${missing_file:?}=value'" ]]

  # ... and when used as values
  run json key@${missing_file:?}
  echo "$output"
  [[ $status == 4 && $output =~ \
    "json(): failed to read file referenced by argument: '${missing_file:?}' from 'key@${missing_file:?}'" ]]
}

@test "json errors are signaled in-band by writing a 0x18 Cancel control character" {
  local bad_number=abc
  local bad_number_file=$(mktemp_bats); printf def > "${bad_number_file:?}"
  declare -A examples=(
    [bad_defaults_cmd]='ok'            [bad_defaults_status]=2     [bad_defaults_defaults]='type=bad'
    [arg_syntax_error_cmd]='foo:[=bar'  [arg_syntax_error_status]=2
    [bad_return_cmd]='ok'              [bad_return_status]=2       [bad_return_return]='bad'

    [unbound_key_var_cmd]='@__bad='      [unbound_key_var_status]=3
    [unbound_val_var_cmd]='a@__bad'     [unbound_val_var_status]=3
    [missing_key_file_cmd]='@./__bad='   [missing_key_file_status]=4
    [missing_val_file_cmd]='a@./__bad=' [missing_val_file_status]=4

    [invalid_val_file_cmd]="a:number@${bad_number_file:?}"         [invalid_val_file_status]=1
    [invalid_val_array_file_cmd]="a:number[]@${bad_number_file:?}" [invalid_val_array_file_status]=1
    [invalid_val_var_cmd]="a:number@bad_number"                    [invalid_val_var_status]=1
    [invalid_val_array_var_cmd]="a:number[]@bad_number"            [invalid_val_array_var_status]=1
    [invalid_val_str_cmd]="a:number=bad"                            [invalid_val_str_status]=1
    [invalid_val_array_str_cmd]="a:number[]=bad"                    [invalid_val_array_str_status]=1
  )
  readarray -t example_names < \
    <(grep -P '_cmd$' <(printf '%s\n' "${!examples[@]}") | sed -e 's/_cmd$//' | sort)

  for name in "${example_names[@]:?}"; do
    local defaults=${examples[${name:?}_defaults]:-}
    local return=${examples[${name:?}_return]:-}
    local expected_status=${examples[${name:?}_status]:?}
    local cmd=${examples[${name:?}_cmd]:?}

    for json_stream in '' true; do
      json_return=${return?} json_defaults=${defaults?} \
        run --separate-stderr json "${cmd:?}"
      [[ $status == $expected_status && $stderr =~ "json():" \
        && ${output:(( ${#output} - 1 ))} == $'\x18' ]]

      local buff=() status=0
      json_return=${return?} json_defaults=${defaults?} out=buff json "${cmd:?}" || status=$?
      [[ $status == $expected_status && ${buff[-1]} == $'\x18' ]]
      echo "name=${name@Q} json_stream=${json_stream@Q}"
    done
  done
}

@test "json.bash the stream-poisoning Cancel character is visually marked with ␘ when the output is an interactive terminal" {
  local stdout=$(mktemp_bats) stderr=$(mktemp_bats) status=0

  # Running under script simulates an interactive terminal
  SHELL=$(command -v bash) ERR=${stderr:?} \
    script -qefc '. json.bash; json a:number=oops 2> "${ERR:?}"' /dev/null \
    > "${stdout:?}" || status=$?

  # Output contains both a real 0x18 Cancel char, and a symbolic version:
  diff -u <(printf '\x18␘\r\n') "${stdout:?}"
  # Note: We see \r\n despite printing \n because TTYs translate \n into \r\n,
  # e.g. see: https://pexpect.readthedocs.io/en/stable/overview.html#find-the-end-of-line-cr-lf-conventions

  err="json.encode_number(): not all inputs are numbers: 'oops'
json(): failed to encode value as number: 'oops' from 'a:number=oops'
"
  diff -u <(printf "${err:?}") "${stderr:?}"
  [[ $status == 1 ]]
}

@test "json.bash json non-errors" {
  # Edge-cases related to the above errors that are not errors
  # a=b=c is parsed as a value a: "a=b"
  json a=b=c | equals_json '{a: "b=c"}'

  # keys can contain '-' after the first char
  json a-b=c | equals_json '{"a-b": "c"}'

  # type by itself is OK with or without an array marker
  json :string | equals_json '{"": ""}'
  json :string[] | equals_json '{"": []}'

  # raw arrays with empty values are not checked for or detected.
  raws=('' '')
  [[ $(json a:raw[]@raws) == '{"a":[,]}' ]]

  # invalid raw values are not checked for or detected
  [[ $(json a:raw=']  ') == '{"a":]  }' ]]
}

@test "json streaming output with json_stream=true :: arrays" {
  # By default json collects output in a buffer and only emits it in one go.
  # This behaviour is intended to prevent partial output in the case of errors.
  # But incremental output can be desirable when stream-encoding from a pipe or
  # large file.
  in_pipe=$(mktemp_bats --dry-run); out_pipe=$(mktemp_bats --dry-run)
  mkfifo "${in_pipe:?}" "${out_pipe:?}"

  json_buffered_chunk_count=1 json_stream=true \
    json before="I am first!" content:json[]@${in_pipe:?} after="I am last!" \
    > "${out_pipe:?}" &

  exec 7<"${out_pipe:?}"  # open the in/out pipes
  exec 6>"${in_pipe:?}"

  expect_read 7 '{"before":"I am first!","content":['
  json msg="Knock knock!" >&6
  expect_read 7 '{"msg":"Knock knock!"}'
  json msg="Who is there?" >&6
  expect_read 7 ',{"msg":"Who is there?"}'
  exec 6>&-  # close the input
  expect_read 7 $'],"after":"I am last!"}\n'
  exec 7>&-  # close the output
  wait %1
}

@test "json streaming output with json_stream=true :: string/raw" {
  # As well as arrays, the string and raw types support streamed output from
  # files. The result of this is that string and raw values are written out
  # incrementally, without buffering the whole value in memory. This test
  # demonstrates this by writing string and raw values across several separate
  # writes, while reading the partial output as it's emitted.
  in_key=$(mktemp_bats --dry-run) in_string=$(mktemp_bats --dry-run);
  in_raw=$(mktemp_bats --dry-run); out_pipe=$(mktemp_bats --dry-run);
  mkfifo "${in_key:?}" "${in_string:?}" "${in_raw:?}" "${out_pipe:?}"

  json_chunk_size=12 json_stream=true json \
    streamed_string@"${in_string:?}" \
    @"${in_key:?}=My property name is streamed" \
    streamed_raw:raw@"${in_raw:?}" \
    > "${out_pipe:?}" &

  exec 7<"${out_pipe:?}"  # open the output that json is writing to

  # Generate the string value of the first property
  exec 6>"${in_string:?}"  # open the pipe that json is reading the string from
  expect_read 7 '{"streamed_string":"'
  printf 'This is the ' >&6
  expect_read 7 'This is the '
  printf 'content of t' >&6
  expect_read 7 'content of t'
  printf 'he string.\n\n' >&6
  expect_read 7 'he string.\n\n'
  exec 6>&-  # close in_string

  # Generate the property name of the second property
  exec 6>"${in_key:?}"
  printf 'This is the property name' >&6
  expect_read 7 '","This is the property nam'
  printf '. It could be quite long, but probably best not to do that.' >&6
  expect_read 7 'e. It could be quite long, but probably best not'
  exec 6>&-  # close in_key

  expect_read 7 ' to do that.":"My property name is streamed","streamed_raw":'

  # Generate the raw value of the third property
  exec 6>"${in_raw:?}"
  printf '[' >&6
  json msg="I'm in ur script" >&6
  expect_read 7 '[{"msg":"I'\''m in ur scrip'
  printf ',' >&6
  json msg="generating JSON" >&6
  printf ']' >&6
  expect_read 7 $'t"}\n,{"msg":"generating '
  exec 6>&-  # close in_raw
  expect_read 7 $'JSON"}\n]}\n'

  exec 7>&-  # close the output
  wait %1
}

@test "json.bash CLI :: help" {
  for flag in -h --help; do
    run ./json.bash "$flag"
    [[ $status == 0 ]]
    [[ $output =~ Generate\ JSON\. ]]
    [[ $output =~ Usage: ]]
  done
}

@test "json.bash CLI :: version" {
  run ./json.bash --version
  [[ $status == 0 ]]
  [[ $output == '{"name":"json.bash","version":"'"${JSON_BASH_VERSION:?}"'","web":"https://github.com/h4l/json.bash"}' ]]
}

@test "json.bash CLI :: object output" {
  # The CLI forwards its arguments to the json() function
  run ./json.bash "The Message"="Hello World" size:number=42
  [[ $status == 0 && $output == '{"The Message":"Hello World","size":42}' ]]
}

@test "json.bash CLI :: array output via prog name" {
  # The CLI uses json_return=array (like json.array()) when the program name has
  # the suffix "array"
  dir=$(mktemp_bats -d)
  ln -s "${BATS_TEST_DIRNAME:?}/json.bash" "${dir:?}/xxx-array"
  run "${dir:?}/xxx-array" foo bar
  [[ $status == 0 && $output == '["foo","bar"]' ]]
}

@test "json validator :: validates valid JSON via arg" {
  initials=('' 'true' '{}' '[]' '42' '"hi"' 'null')
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    json.validate "${_initials[@]}" 'true'
    json.validate "${_initials[@]}" 'false'
    json.validate "${_initials[@]}" 'null'
    json.validate "${_initials[@]}" '42'
    json.validate "${_initials[@]}" '"abc"'
    json.validate "${_initials[@]}" '[]'
    json.validate "${_initials[@]}" '[-1.34e+4,2.1e-4,2e6]'
    json.validate "${_initials[@]}" '{}'
    json.validate "${_initials[@]}" '{"foo":{"bar":["baz"]}}'
  done
}

@test "json validator :: validates valid JSON via array" {
  in=input
  input=(); json.validate

  initials=('' 'true' '{}' '[]' '42' '"hi"' 'null')
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    input=("${_initials[@]}" 'true'); json.validate
    input=("${_initials[@]}" 'false'); json.validate
    input=("${_initials[@]}" 'null'); json.validate
    input=("${_initials[@]}" '42'); json.validate
    input=("${_initials[@]}" '"abc"'); json.validate
    input=("${_initials[@]}" '[]'); json.validate
    input=("${_initials[@]}" '[-1.34e+4,2.1e-4,2e6]'); json.validate
    input=("${_initials[@]}" '{}'); json.validate
    input=("${_initials[@]}" '{"foo":{"bar":["baz"]}}'); json.validate
  done
}

@test "json validator :: validates JSON with insignificant whitespace" {
  local ws_chars=($' \t\n\r') src
  for i in 0 1 2 3; do
    spaced_json_template=' { "a" : [ "c" , [ { } ] ] , "b" : null } '
    ws="${ws_chars:$i:1}"
    spaced_json=${spaced_json_template// /"${ws:?}"}
    json.validate "${spaced_json:?}"
    src=("${spaced_json:?}"); in=src json.validate

    ws="${ws_chars:$i:4}${ws_chars:0:$i}"
    spaced_json=${spaced_json_template// /"${ws:?}"}
    json.validate "${spaced_json:?}"
    src=("${spaced_json:?}"); in=src json.validate
  done
  [[ $i == 3 ]]
}

function expect_json_args_invalid() {
  if [[ $# == 0 ]]; then return 1; fi
  if json.validate "$@"; then
    echo "expect_invalid: example unexpectedly passed validation: ${1@Q}" >&2
    return 1
  fi
}

@test "json validator :: detects invalid JSON via arg" {
  initials=('' true)
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    expect_json_args_invalid "${_initials[@]}" ''
    expect_json_args_invalid "${_initials[@]}" 'truex'
    expect_json_args_invalid "${_initials[@]}" 'false_'
    expect_json_args_invalid "${_initials[@]}" 'nullx'
    expect_json_args_invalid "${_initials[@]}" '42a'
    expect_json_args_invalid "${_initials[@]}" '"abc'
    expect_json_args_invalid "${_initials[@]}" '"ab\z"' # invalid escape
    expect_json_args_invalid "${_initials[@]}" '"ab""ab"'
    expect_json_args_invalid "${_initials[@]}" '['
    expect_json_args_invalid "${_initials[@]}" '[]]'
    expect_json_args_invalid "${_initials[@]}" '[][]'
    expect_json_args_invalid "${_initials[@]}" '[a]'
    expect_json_args_invalid "${_initials[@]}" '{'
    expect_json_args_invalid "${_initials[@]}" '{}{}'
    expect_json_args_invalid "${_initials[@]}" '{42:true}'
    expect_json_args_invalid "${_initials[@]}" '{"foo":}'
  done
}

function expect_json_array_invalid() {
  local input=("$@")
  if in=input json.validate; then
    echo "expect_invalid: example unexpectedly passed validation: ${input[*]@Q}" >&2
    return 1
  fi
}

@test "json validator :: detects invalid JSON via array" {
  expect_json_array_invalid ''
  initials=('' true)
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    expect_json_array_invalid "${_initials[@]}" 'truex'
    expect_json_array_invalid "${_initials[@]}" 'false_'
    expect_json_array_invalid "${_initials[@]}" 'nullx'
    expect_json_array_invalid "${_initials[@]}" '42a'
    expect_json_array_invalid "${_initials[@]}" '"abc'
    expect_json_array_invalid "${_initials[@]}" '"ab\z"' # invalid escape
    expect_json_array_invalid "${_initials[@]}" '"ab""ab"'
    expect_json_array_invalid "${_initials[@]}" '['
    expect_json_array_invalid "${_initials[@]}" '[]]'
    expect_json_array_invalid "${_initials[@]}" '[][]'
    expect_json_array_invalid "${_initials[@]}" '[a]'
    expect_json_array_invalid "${_initials[@]}" '{'
    expect_json_array_invalid "${_initials[@]}" '{}{}'
    expect_json_array_invalid "${_initials[@]}" '{42:true}'
    expect_json_array_invalid "${_initials[@]}" '{"foo":}'
  done
}

function expect_json_valid() {
  (( $# > 0 ))
  : ${type?"\$type must be set"}

  json.validate "$@"
  local args=("$@")
  in=args json.validate

  for col in array object; do
    col_type="${type:?}_${col:?}"

    local example; for example in "$@"; do
      args=(); out=args json_return=${col:?} json @example:json

      type=${col_type:?} json.validate "${args:?}"
      type=${col_type:?} in=args json.validate
    done
  done
}

function expect_json_invalid() {
  (( $# > 0 ))
  : ${type?"\$type must be set"}

  # validate individually to avoid invalid examples masking invalid ones
  local example; for example in "$@"; do
    expect_json_args_invalid "${example:?}"
    expect_json_array_invalid "${example:?}"

    for col in array object; do
      col_type="${type:?}_${col:?}"

      declare -p type example col
      local args=(); out=args json_return=${col:?} json @example:json
      declare -p type example col args
      type=${col_type:?} expect_json_args_invalid "${args[@]:?}"
      type=${col_type:?} expect_json_array_invalid "${args[@]:?}"
    done
  done
}

@test "json validator :: validates JSON sub-type" {

  type=json expect_json_valid '{"a":1}' 'true' '"foo"'
  # no invalid examples as all valid JSON is valid for the json type!

  type=string expect_json_valid '"foo"' '""'
  type=string expect_json_invalid '{}' '[]' 42 true false null

  type=number expect_json_valid 0 1 42 -0.12e+6
  type=number expect_json_invalid '{}' '[]' '"foo"' true false null

  type=bool expect_json_valid true false
  type=bool expect_json_invalid '{}' '[]' '"foo"' 42 null

  type=true expect_json_valid true
  type=true expect_json_invalid '{}' '[]' '"foo"' 42 false null

  type=false expect_json_valid false
  type=false expect_json_invalid '{}' '[]' '"foo"' 42 true null

  type=null expect_json_valid null
  type=null expect_json_invalid '{}' '[]' '"foo"' 42 true false
}

function assert_array_equals() {
  local -n left=${1:?} right=${2:?}
  if [[ ! ( ${#left[@]} == 0 || ${left@a} == *[aA]* ) ]]; then
    echo "assert_array_equals: left is not an array var" >&2; return 1
  fi
  if [[ ! ( ${#right[@]} == 0 || ${right@a} == *[aA]* ) ]]; then
    echo "assert_array_equals: right is not an array var" >&2; return 1
  fi

  diff -u <(printf '%s\n' "${!left[@]}" | sort) <(printf '%s\n' "${!right[@]}" | sort) || {
    echo "assert_array_equals: arrays have different keys" >&2; return 1
  }

  for i in "${!left[@]}"; do
    if [[ ${left[$i]} != "${right[$i]}" ]]; then
      echo "assert_array_equals: arrays are unequal at index ${i@Q}:" \
        "${left[$i]@Q} != ${right[$i]@Q}" >&2
      return 1
    fi
  done
}

function expect_read() {
  local fd=${1:?} expected=${2:?} status=0
  read -r -t 1 -N "${#expected}" -u "${fd:?}" actual || status=$?
  if (( $status > 128 )); then
    echo "expect_read: read FD ${fd:?} timed out" >&2
    return 1
  elif (( $status > 0 )); then
    echo "expect_read: read returned status=$status" >&2
  fi

  if [[ $expected != "$actual" ]]; then
    echo "expect_read: read result did not match expected:" \
      "expected=${expected@Q}, actual=${actual@Q}" >&2
    return 1
  fi
}
