"""Wait for the launched app to export its rendered UI, then preserve the PNG."""
import pathlib
import shutil
import sys
import time

source, destination = map(pathlib.Path, sys.argv[1:])
deadline = time.monotonic() + 30
while time.monotonic() < deadline:
    if source.is_file() and source.stat().st_size > 0:
        shutil.copyfile(source, destination)
        print(f"Captured {destination.name} ({destination.stat().st_size} bytes)")
        break
    time.sleep(0.1)
else:
    raise SystemExit(f"The app did not export {source.name} within 30 seconds")
