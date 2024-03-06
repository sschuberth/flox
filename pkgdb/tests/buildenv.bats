#! /usr/bin/env bats
# --------------------------------------------------------------------------- #
#
# @file tests/buildenv.bats
#
# @brief Test building environments from lockfiles.
#
# Relies on lockfiles generated by `pkgdb` from flox manifests.
#
# These tests only check the build segment,
# they do not check the resolution of manifests,
# nor the activation of the resulting environments.
# Such tests are found in `pkgdb` and `flox` respectively.
#
#
# --------------------------------------------------------------------------- #
#
# TODO: Allow a path to a file to be passed.
#
#
# --------------------------------------------------------------------------- #

# bats file_tags=build-env

load setup_suite.bash

# --------------------------------------------------------------------------- #

setup_file() {
  : "${CAT:=cat}"
  : "${TEST:=test}"
  : "${MKDIR:=mkdir}"
  export CAT TEST MKDIR
  export LOCKFILES="${BATS_FILE_TMPDIR?}/lockfiles"

  # Always use a consistent `nixpkgs' input.
  export _PKGDB_GA_REGISTRY_REF_OR_REV="${NIXPKGS_REV?}"

  # Generate lockfiles
  for dir in "${TESTS_DIR?}"/data/buildenv/lockfiles/*; do
    if $TEST -d "$dir"; then
      _lockfile="${LOCKFILES?}/${dir##*/}/manifest.lock"
      $MKDIR -p "${_lockfile%/*}"
      ${PKGDB_BIN?} manifest lock --ga-registry --manifest \
        "$dir/manifest.toml" > "$_lockfile"
    fi
  done
}

# ---------------------------------------------------------------------------- #

# bats test_tags=single,smoke
@test "Simple environment builds successfully" {
  run "$PKGDB_BIN" buildenv "$LOCKFILES/single-package/manifest.lock"
  assert_success
}

# bats test_tags=single,smoke
@test "Inline JSON builds successfully" {
  run "$PKGDB_BIN" buildenv "$(< "$LOCKFILES/single-package/manifest.lock")"
  assert_success
}

# ---------------------------------------------------------------------------- #


# ---------------------------------------------------------------------------- #

# bats test_tags=single,binaries
@test "Built environment contains binaries" {
  run "$PKGDB_BIN" buildenv \
    "$LOCKFILES/single-package/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_success
  assert "$TEST" -x "$BATS_TEST_TMPDIR/env/bin/vim"
}

# bats test_tags=single,activate-files
@test "Built environment contains activate files" {
  run "$PKGDB_BIN" buildenv \
    "$LOCKFILES/single-package/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_success
  assert "$TEST" -f "$BATS_TEST_TMPDIR/env/activate/bash"
  assert "$TEST" -f "$BATS_TEST_TMPDIR/env/activate/zsh"
  assert "$TEST" -d "$BATS_TEST_TMPDIR/env/etc/profile.d"
}

# --------------------------------------------------------------------------- #

# bats test_tags=hook,script
@test "Built environment includes hook script" {
  run "$PKGDB_BIN" buildenv "$LOCKFILES/hook-script/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_success
  assert "$TEST" -f "$BATS_TEST_TMPDIR/env/activate/hook.sh"
  run "$CAT" "$BATS_TEST_TMPDIR/env/activate/hook.sh"
  assert_output "script"
}

@test "Built enviroment includes 'on-activate' script" {
  run "$PKGDB_BIN" buildenv "$LOCKFILES/on-activate/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_success
  assert "$TEST" -f "$BATS_TEST_TMPDIR/env/activate/on-activate.sh"
}

# --------------------------------------------------------------------------- #

# bats test_tags=conflict,detect
@test "Detects conflicting packages" {
  run "$PKGDB_BIN" buildenv "$LOCKFILES/conflict/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_failure
  assert_output --regexp "'vim.*' conflicts with 'vim.*'"
}

# bats test_tags=conflict,resolve
@test "Allows to resolve conflicting with priority" {
  run "$PKGDB_BIN" buildenv \
    "$LOCKFILES/conflict-resolved/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_success
}

# ---------------------------------------------------------------------------- #

# Single quotes in variables should be escaped.
# Similarly accidentally escaped single quotes like
#
# [vars]
# singlequoteescaped = "\\'baz"
#
# should be escaped and printed as  \'baz  (literally)
# bats test_tags=buildenv:vars
@test "Environment escapes variables" {
  run "$PKGDB_BIN" buildenv "$LOCKFILES/vars_escape/manifest.lock" \
    --out-link "$BATS_TEST_TMPDIR/env"
  assert_success

  assert "$TEST" -f "$BATS_TEST_TMPDIR/env/activate/bash"
  run "$CAT" "$BATS_TEST_TMPDIR/env/activate/bash"
  assert_line "export singlequotes=''\''bar'\'''"
  assert_line "export singlequoteescaped='\'\''baz'"
}

# ---------------------------------------------------------------------------- #

# With '--container' produces a script that can be used to build a container.
# bats test_tags=buildenv:container
@test "Environment builds container" {
  run "$PKGDB_BIN" buildenv "$LOCKFILES/single-package/manifest.lock" \
    --container \
    --out-link "$BATS_TEST_TMPDIR/container-builder"
  assert_success

  # Run the container builder script.
  run bash -c '"$BATS_TEST_TMPDIR/container-builder" > "$BATS_TEST_TMPDIR/container"'
  assert_success

  # Check that the container is a tar archive.
  run tar -tf "$BATS_TEST_TMPDIR/container"
  # Check that the container contains layer(s)
  assert_output --regexp '([a-z0-9]{64}/layer.tar)+'
  # Check that the container contains a config file.
  assert_output --regexp '([a-z0-9]{64}\.json)'
  # Check that the container contains a manifest file.
  assert_line 'manifest.json'
}

# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
