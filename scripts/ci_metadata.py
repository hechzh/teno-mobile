"""GitHub job output contains only public Android version metadata."""
import re
from pathlib import Path
source=(Path(__file__).resolve().parents[1]/'app/build.gradle').read_text()
print('version='+re.search(r"versionName\s+['\"]([^'\"]+)",source)[1])
print('version_code='+re.search(r'versionCode\s+(\d+)',source)[1])
