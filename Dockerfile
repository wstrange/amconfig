# Dockerfile to package this app up so we can run it on kubernetes
# This will run pub get and build the app.
# When run it expects to find bin/server.dart
FROM google/dart-runtime

