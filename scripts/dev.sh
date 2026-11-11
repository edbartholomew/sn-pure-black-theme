#!/bin/sh
# Serve the repo for local testing and rebuild whenever src/theme.css changes.
cd "$(dirname "$0")/.."

# Refetch the upstream CSS on each start, then reuse it for the rebuilds below.
rm -f dist/upstream.css
./scripts/build.sh

# Static server with CORS on and caching off, so the app always gets the latest build
npx --yes http-server . -p 8000 --cors -c-1 -s &
server=$!
trap 'kill $server' EXIT
echo "Serving http://localhost:8000/ext.dev.json"

# Poll the file's modification time. No file watcher, so no dependency beyond the shell.
last=$(stat -f %m src/theme.css)
while sleep 1; do
	now=$(stat -f %m src/theme.css)
	if [ "$now" != "$last" ]; then
		last=$now
		./scripts/build.sh
	fi
done
