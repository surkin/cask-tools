#!/usr/bin/env bats
load ../lib/cask-scripts/general

@test "syntax_error() when PROGRAM='example' and argument 'unexpected error'" {
  PROGRAM='example'
  run syntax_error 'unexpected error'
  [ "${status}" -eq 1 ]
  [ "${lines[0]}" == 'example: unexpected error' ]
  [ "${lines[1]}" == 'Try `example --help` for more information.' ]
}

@test "error() with argument 'unexpected error'" {
  run error 'unexpected error'
  [ "${status}" -eq 1 ]
  [ "${output}" == "$(tput setaf 1)unexpected error$(tput sgr0)" ]
}

# version()
@test "version() when VERSION global is set to 1.0.0" {
  readonly VERSION='1.0.0'
  run version
  [ "${status}" -eq 0 ]
  [ "${output}" == '1.0.0' ]
}

# unquote()
@test "unquote() when single quotes: 'test' => test" {
  run unquote <<< "'test'"
  [ "${output}" == 'test' ]
}

@test "unquote() when single quotes and comma at the end: 'test', => test" {
  run unquote <<< "'test',"
  [ "${output}" == 'test' ]
}

@test "unquote() when double quotes': \"test\" => test" {
  run unquote <<< '"test"'
  [ "${output}" == 'test' ]
}

@test "unquote() when double quotes and comma at the end: \"test\", => test" {
  run unquote <<< '"test",'
  [ "${output}" == 'test' ]
}

@test "unquote() when double quotes not normalized: \"test' => \"test', 'test\" => 'test\"" {
  run unquote <<< "\"test'"
  [ "${output}" == "\"test'" ]
  run unquote <<< "'test\""
  [ "${output}" == "'test\"" ]
}

# check_array_contains()
@test "check_array_contains() when no arguments" {
  run check_array_contains
  [ "${status}" -eq 1 ]
}

@test "check_array_contains() when element doesn't exists in array" {
  local -a array
  readonly array=('one' 'two' 'three')
  run check_array_contains 'array[@]' 'four'
  [ "${status}" -eq 1 ]
}

@test "check_array_contains() when element exists in array" {
  local -a array
  readonly array=('one' 'two' 'three')
  run check_array_contains 'array[@]' 'one'
  [ "${status}" -eq 0 ]
  run check_array_contains 'array[@]' 'two'
  [ "${status}" -eq 0 ]
  run check_array_contains 'array[@]' 'three'
  [ "${status}" -eq 0 ]
}

# get_xml_config_values()
@test "get_xml_config_values() when no arguments" {
  run get_xml_config_values
  [ "${status}" -eq 1 ]
}

@test "get_xml_config_values() when arguments passed but config path not set" {
  run get_xml_config_values '//version-delimiter-build' 'cask'
  [ "${status}" -eq 1 ]
}

@test "get_xml_config_values() when arguments passed but config path is invalid" {
  readonly CONFIG_FILE_XML='invalid/path.xml'
  run get_xml_config_values '//version-delimiter-build' 'cask'
  [ "${status}" -eq 1 ]
}

@test "get_xml_config_values() when return single value (version-delimiter-build)" {
  local -a result
  readonly CONFIG_FILE_XML="${BATS_TEST_DIRNAME}/config/cask-check-updates.xml"
  run get_xml_config_values '//version-delimiter-build' 'cask'
  echo ${output}
  readonly result=(${output})
  [ "${status}" -eq 0 ]
  [ "${#result[@]}" -eq 2 ]
  [ "${result[0]}" == 'codekit' ]
  [ "${result[1]}" == 'evernote' ]
}

@test "get_xml_config_values() when return single value (version-only)" {
  local -a result
  readonly CONFIG_FILE_XML="${BATS_TEST_DIRNAME}/config/cask-check-updates.xml"
  run get_xml_config_values '//version-only' 'cask'
  readonly result=(${output})
  [ "${status}" -eq 0 ]
  [ "${#result[@]}" -eq 1 ]
  [ "${result[0]}" == 'framer' ]
}

@test "get_xml_config_values() when return single value (build-only)" {
  local -a result
  readonly CONFIG_FILE_XML="${BATS_TEST_DIRNAME}/config/cask-check-updates.xml"
  run get_xml_config_values '//build-only' 'cask'
  readonly result=(${output})
  [ "${status}" -eq 0 ]
  [ "${#result[@]}" -eq 1 ]
  [ "${result[0]}" == 'daemon-tools-lite' ]
}

@test "get_xml_config_values() when return single value (matching-tag)" {
  local -a result
  readonly CONFIG_FILE_XML="${BATS_TEST_DIRNAME}/config/cask-check-updates.xml"
  run get_xml_config_values '//matching-tag/cask/@tag' '../.' '.'
  readonly result=(${output})
  [ "${status}" -eq 0 ]
  [ "${#result[@]}" -eq 2 ]
  [ "${result[0]}" == 'adobe-bloodhound' ]
  [ "${result[1]}" == 'Bloodhound' ]
}

# add_to_review() and show_review()
@test "add_to_review() and show_review() when one named value added" {
  add_to_review 'Name' 'value one'
  run show_review
  [ "${status}" -eq 0 ]
  [ "${output}" == 'Name:   value one' ]
}

@test "add_to_review() and show_review() when one unnamed value added" {
  add_to_review '' 'value one'
  run show_review
  [ "${status}" -eq 0 ]
  [ "${output}" == 'value one' ]
}

@test "add_to_review() and show_review() when multiple named values added and one with longer name" {
  add_to_review 'Name' 'value one'
  add_to_review 'Longer name' 'value two'
  run show_review
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" == 'Name:          value one' ]
  [ "${lines[1]}" == 'Longer name:   value two' ]
}

@test "add_to_review() and show_review() when multiple named values added and one doesn't have name" {
  add_to_review 'Name' 'value one'
  add_to_review '' 'value two'
  run show_review
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" == 'Name:   value one' ]
  [ "${lines[1]}" == '        value two' ]
}

@test "add_to_review() and show_review() when multiple named values added and optional length argument is passed" {
  add_to_review 'Name' 'value one'
  add_to_review 'Longer name' 'value two'
  run show_review 20
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" == 'Name:               value one' ]
  [ "${lines[1]}" == 'Longer name:        value two' ]
}

@test "show_review() when nothing to display" {
  run show_review
  [ "${status}" -eq 1 ]
}

@test "show_review() when displayed once globals should be resetted" {
  add_to_review 'Name' 'value one'
  show_review
  run show_review
  [ "${status}" -eq 1 ]
}

# random()
@test "random() when no arguments" {
  run random
  [ "${status}" -eq 1 ]
}

@test "random() when specified length is 16" {
  run random 16
  [ "${status}" -eq 0 ]
  [ "${#output}" -eq 16 ]
}

# join_by()
@test "join_by() when no arguments" {
  run join_by
  [ "${status}" -eq 1 ]
}

@test "join_by() when separator is commma: ','" {
  local -a array
  readonly array=('one' 'two' 'three')
  run join_by ',' "${array[@]}"
  [ "${status}" -eq 0 ]
  [ "${output}" == 'one,two,three' ]
}

@test "join_by() when separator is commma with space: ', '" {
  local -a array
  readonly array=('one' 'two' 'three')
  run join_by ', ' "${array[@]}"
  [ "${status}" -eq 0 ]
  [ "${output}" == 'one, two, three' ]
}

# highlight()
@test "highlight() when no arguments" {
  run highlight
  [ "${status}" -eq 1 ]
}

@test "highlight() when highlight a specific part of the string" {
  run highlight 'https://www.example.com/' 'www' 'www' 7
  [ "${status}" -eq 0 ]
  [ "${output}" == "https://$(tput setaf 7)www$(tput sgr0).example.com/" ]
}

# highlight_diff()
@test "highlight_diff() when no arguments" {
  run highlight_diff
  [ "${status}" -eq 1 ]
}

@test "highlight_diff() when first difference highlighted" {
  run highlight_diff 'http://example.com/' 'https://example.com/'
  [ "${status}" -eq 0 ]
  [ "${output}" == "http$(tput setaf 7)s$(tput sgr0)://example.com/" ]

  run highlight_diff 'http://example.com/' 'http://www.example.com/'
  [ "${status}" -eq 0 ]
  [ "${output}" == "http://$(tput setaf 7)www.$(tput sgr0)example.com/" ]

  run highlight_diff 'http://example.com/' 'http://test.example.com/'
  [ "${status}" -eq 0 ]
  [ "${output}" == "http://$(tput setaf 7)test.$(tput sgr0)example.com/" ]
}

@test "highlight_diff() if color resets when only last character added" {
  run highlight_diff 'http://example.com' 'http://example.com/'
  [ "${status}" -eq 0 ]
  echo "${output}"
  [ "${output}" == "http://example.com$(tput setaf 7)/$(tput sgr0)" ]
}

# extract_version()
@test "extract_version(): 1.0.1 => 1.0.1" {
  run extract_version '1.0.1'
  [ "${output}" == '1.0.1' ]
}

@test "extract_version(): v1.0.1 => 1.0.1" {
  run extract_version 'v1.0.1'
  [ "${output}" == '1.0.1' ]
}

@test "extract_version(): Version1.0.1 => 1.0.1" {
  run extract_version 'Version1.0.1'
  [ "${output}" == '1.0.1' ]
}

@test "extract_version(): Version-1.0.1 => 1.0.1" {
  run extract_version 'Version-1.0.1'
  [ "${output}" == '1.0.1' ]
}

@test "extract_version(): Version 1.0.1 => 1.0.1" {
  run extract_version 'Version 1.0.1'
  [ "${output}" == '1.0.1' ]
}

@test "extract_version(): 1.0b1 => 1.0b1" {
  run extract_version '1.0b1'
  [ "${output}" == '1.0b1' ]
}

@test "extract_version(): 1.0beta1 => 1.0beta1" {
  run extract_version '1.0beta1'
  [ "${output}" == '1.0beta1' ]
}

@test "extract_version(): 1.0.beta.1 => 1.0.beta.1" {
  run extract_version '1.0.beta.1'
  [ "${output}" == '1.0.beta.1' ]
}

@test "extract_version(): 1.0.1 (1000) => 1.0.1" {
  run extract_version '1.0.1 (1000)'
  [ "${output}" == '1.0.1' ]
}

@test "extract_version(): 1.0.1 (1.0.0) => 1.0.1" {
  run extract_version '1.0.1 (1.0.0)'
  [ "${output}" == '1.0.1' ]
}

# compare_versions()
@test "compare_versions() when versions are equal: 1 = 1" {
  run compare_versions '1' '1'
  [ "${status}" -eq 0 ]
}

@test "compare_versions() when versions are equal: 200 = 200" {
  run compare_versions '200' '200'
  [ "${status}" -eq 0 ]
}

@test "compare_versions() when versions are equal: 3.0 = 3.0" {
  run compare_versions '3.0' '3.0'
  [ "${status}" -eq 0 ]
}

@test "compare_versions() when versions are equal: 4.0.0 = 4.0.0" {
  run compare_versions '4.0.0' '4.0.0'
  [ "${status}" -eq 0 ]
}

@test "compare_versions() when versions are equal: 5.0rc1 = 5.0rc1" {
  run compare_versions '5.0rc1' '5.0rc1'
  [ "${status}" -eq 0 ]
}

@test "compare_versions() when versions are equal: 6.0.beta.1 = 6.0.beta.1" {
  run compare_versions '6.0.beta.1' '6.0.beta.1'
  [ "${status}" -eq 0 ]
}

@test "compare_versions() when first version is greater than second: 2 > 1" {
  run compare_versions '2' '1'
  [ "${status}" -eq 1 ]
}

@test "compare_versions() when first version is greater than second: 201 > 200" {
  run compare_versions '201' '200'
  [ "${status}" -eq 1 ]
}

@test "compare_versions() when first version is greater than second: 3.1 > 3.0" {
  run compare_versions '3.1' '3.0'
  [ "${status}" -eq 1 ]
}

@test "compare_versions() when first version is greater than second: 4.0.1 > 4.0.0" {
  run compare_versions '4.0.1' '4.0.0'
  [ "${status}" -eq 1 ]
}

@test "compare_versions() when first version is greater than second: 5.0rc2 > 5.0rc1" {
  run compare_versions '5.0rc2' '5.0rc1'
  [ "${status}" -eq 1 ]
}

@test "compare_versions() when first version is greater than second: 6.0.beta.2 > 6.0.beta.1" {
  run compare_versions '6.0.beta.2' '6.0.beta.1'
  [ "${status}" -eq 1 ]
}

@test "compare_versions() when first version is less than second: 2 < 3" {
  run compare_versions '2' '3'
  [ "${status}" -eq 2 ]
}

@test "compare_versions() when first version is less than second: 201 < 202" {
  run compare_versions '201' '202'
  [ "${status}" -eq 2 ]
}

@test "compare_versions() when first version is less than second: 3.1 < 3.2" {
  run compare_versions '3.1' '3.2'
  [ "${status}" -eq 2 ]
}

@test "compare_versions() when first version is less than second: 4.0.1 < 4.0.2" {
  run compare_versions '4.0.1' '4.0.2'
  [ "${status}" -eq 2 ]
}

@test "compare_versions() when first version is less than second: 5.0rc2 < 5.0rc3" {
  run compare_versions '5.0rc2' '5.0rc3'
  [ "${status}" -eq 2 ]
}

@test "compare_versions() when first version is less than second: 6.0.beta.2 < 6.0.beta.3" {
  run compare_versions '6.0.beta.2' '6.0.beta.3'
  [ "${status}" -eq 2 ]
}
