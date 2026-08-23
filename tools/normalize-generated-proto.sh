#!/bin/sh
set -eu

# Keep protoc-gen-mbt output compatible with the current MoonBit compiler.
# These rewrites are intentionally limited to generated protobuf sources.
find lib/proto -name '*.mbt' -type f -exec perl -pi -e '
  s/\b(?:Bool|Bytes|Double|Float|Int|Int64|String|UInt|UInt64)::default\(\)/Default::default()/g;
  s/let json\s*:\s*Map\[String, Json\]\s*=\s*\{\}/let json : Map[String, Json] = Map([])/g;
  s/\bkey => raise (\@json\.JsonDecodeError\(\(path, )"Unknown field \\\{key\}"\)\)/(key, _) => raise $1"Unknown field " + key))/g;
' {} +
