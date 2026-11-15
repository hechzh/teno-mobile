"""Configure immutable public CDN bases in an already prepared Web release.

No API routes, account data or credentials are routed to these origins. Defaults
to same-origin hosting; a failed CDN probe falls back to the retained bundle.
"""
import argparse
import html
import json
from pathlib import Path
import re
from urllib.parse import urlparse


def configure(build, bases):
    build = Path(build)
    bases = list(dict.fromkeys(bases))
    origins = []
    for base in bases:
        url = urlparse(base)
        if (url.scheme != 'https' or not url.hostname or url.username or url.password
                or url.query or url.fragment or not url.path.endswith('/')
                or any(c in base for c in ['"', "'", ',', ';', '\\', '\n', ' '])):
            raise ValueError('CDN bases must be absolute immutable HTTPS directories')
        origins.append(url.scheme+'://'+url.netloc)
    index = build/'index.html'
    code = index.read_text(encoding='utf-8')
    assert 'name="teno-cdn"' in code and 'name="teno-main-sha"' in code
    code = re.sub(r'<meta name="teno-cdn" content="[^"]*">',
                  '<meta name="teno-cdn" content="'+html.escape(','.join(bases), quote=True)+'">', code)
    code = re.sub(r'<link data-teno-cdn[^>]*>\n?', '', code)
    code = code.replace('</head>', ''.join('<link data-teno-cdn rel="preconnect" crossorigin href="'+o+'">\n' for o in dict.fromkeys(origins))+'</head>')
    index.write_text(code, encoding='utf-8')
    caddy = build/'deploy/Caddyfile'
    code = caddy.read_text(encoding='utf-8')
    # Regenerate from source, not from an already customized CSP.
    additions = ' '.join(dict.fromkeys(origins))
    if additions:
        for directive in ('script-src', 'font-src', 'connect-src'):
            code = code.replace(directive+" 'self'", directive+" 'self' "+additions)
    caddy.write_text(code, encoding='utf-8')
    (build/'delivery-config.json').write_text(json.dumps({
        'cdn_bases': bases, 'origin_fallback': True, 'probe_timeout_ms': 5000,
        'scope': 'public immutable application resources only',
    }, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('build', type=Path)
    parser.add_argument('--cdn-base', action='append', default=[])
    args = parser.parse_args()
    configure(args.build, args.cdn_base)
