import os
import pytest
import tomlkit

SUPPORTED_SHELLS = ["bash"]
HELLO_PROFILE_COMMON = """echo "Welcome to your flox environment!";"""
HELLO_PROFILE_VARS = """
[vars]
foo = "baz"
"""


@pytest.mark.parametrize("shell", SUPPORTED_SHELLS)
def test_activate_modifies_shell(shell, flox, flox_env, run) -> None:
    output = run([shell, "-c", f"{flox} init"])
    assert flox_env.path.exists()
    assert (flox_env.path / ".flox").exists()
    with flox_env.manifest_path().open("r") as f:
        manifest = tomlkit.load(f)
    manifest["profile"]["common"] = tomlkit.string(
        HELLO_PROFILE_COMMON, multiline=True, escape=False
    )
    manifest["vars"]["foo"] = "baz"
    with flox_env.manifest_path().open("w") as f:
        tomlkit.dump(manifest, f)
    breakpoint()
    run([shell, "-c", f"{flox} install hello"])
    output = run([shell, "-c", f"eval $({flox} activate); type hello; echo $foo"])
    output.check_returncode()
    assert "Welcome to your flox environment" in output.stdout
    assert f"hello is {flox_env.run_path.absolute}" in output.stdout
    assert "baz" in output.stdout
