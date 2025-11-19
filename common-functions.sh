#!/bin/bash
verifyLocalYarnVersion() {
  if ! YARN_VERSION=$(yarn --version|cut -f1 -d'.') || { [ "$YARN_VERSION" != "3" ] && [ "$YARN_VERSION" != "4" ]; }; then
    echo "This script uses yarn@^4+, please install yarn (for example \`corepack enable && corepack prepare yarn@^4 --activate\` and re-try"
    exit 1
  fi
}

verifyJqVersion() {
  JQ_VERSION_WANTED="jq-1.7"
  if ! JQ_VERSION=$(jq --version) || [[ "$JQ_VERSION" != *"$JQ_VERSION_WANTED"* ]]; then
    echo "This script uses $JQ_VERSION_WANTED (found ${JQ_VERSION}), please install jq (for example \`brew install\` on macOS or \`choco install jq\` on windows with choco, then re-try"
  fi
}

verifyDarwinPrequisites() {
  if [ "$(uname)" == "Darwin" ]; then
    # If the keychain is unlocked then this fails in the middle, let's check that now and fail fast
    if ! security show-keychain-info login.keychain > /dev/null 2>&1; then
      echo "Login keychain is not unlocked, codesigning will fail so macCatalyst build wll fail."
      echo "run 'security unlock-keychain login.keychain' to unlock the login keychain then re-run"
      exit 1
    fi

    # We do not want to run under Rosetta 2, brew doesn't work and compiles might not work after
    arch_name="$(uname -m)"
    if [ "${arch_name}" = "x86_64" ]; then
      if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
        echo "Running on Rosetta 2"
        echo "This is not supported. Run \`env /usr/bin/arch -arm64 /bin/bash --login\` then try again"
        exit 1
      else
        echo "Running on native Intel"
      fi
    elif [ "${arch_name}" = "arm64" ]; then
      echo "Running on ARM"
    else
      echo "Unknown architecture: ${arch_name}"
    fi
  fi
}
