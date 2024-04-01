{
  python3,
  writeShellScriptBin,
  PROJECT_NAME ? "flox-integ-tests-py",
}: let
  python_env = python3.withPackages (ps:
    with ps; [
      pytest
      pytest-emoji
      pytest-xdist
      pexpect
      ipdb
      tomlkit
    ]);
in
  writeShellScriptBin PROJECT_NAME ''
    ${python_env}/bin/pytest -n0
  ''
