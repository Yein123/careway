# Source before running emulators or functions tests: `source tool/dev-env.sh`
# Firebase emulators need JDK 21+; Cloud Functions target Node 22.
export JAVA_HOME="$HOME/.jdks/jdk-21.0.12.1+1"
export PATH="$JAVA_HOME/bin:$HOME/.node/node-v22.23.3-win-x64:$PATH"
export FUNCTIONS_DISCOVERY_TIMEOUT=60
