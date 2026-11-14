{ pkgs }:

pkgs.runCommand "hermes-agent-lifecycle-tests"
{
  nativeBuildInputs = with pkgs; [ bash coreutils findutils gnugrep gnutar gzip jq python3 shellcheck-minimal util-linux ];
}
''
  export PYTHONDONTWRITEBYTECODE=1
  shellcheck --shell=bash ${../hermes-container.sh} ${../container/entrypoint.sh} ${../container/shellrc} ${./lifecycle.sh}
  bash ${./lifecycle.sh} ${../hermes-container.sh} ${../container}
  mkdir -p fixture/tests
  cp ${./test_routing.py} fixture/tests/test_routing.py
  ln -s ${../runtime} fixture/runtime
  python3 -m unittest discover -s fixture/tests
  touch "$out"
''
