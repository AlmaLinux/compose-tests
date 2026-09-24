#!/usr/bin/env python3
"""Digest of the repository state that compose-tests ran against.

For every gated repository (see GATED) the package digest covers the set of
"<pkgid>  <name>-<epoch>:<version>-<release>.<arch>" lines from other.xml.
pkgid is the sha256 of the RPM file itself, so the digest does not depend on
the file layout (Pulp keeps Packages/<letter>/, published copies usually
Packages/) or on when the metadata was generated. Repositories with modular
metadata get a second digest over their modules.yaml.

CI runs it against Pulp and publishes the result as the "compose-state"
annotation of the job. The fs mode digests any other copy of the same
repositories, a local tree or a mirror, so whoever publishes them can check
that they publish exactly a tested state. The record carries "alg", a hash
of this file: digests are comparable only when both sides ran the same code,
so a copy used elsewhere has to stay byte-identical to this one.

Usage:
  compose_state.py pulp --version 10 --arch x86_64 [--sources pulp]
  compose_state.py fs --version 10 --arch x86_64 --root https://repo.almalinux.org/almalinux/10
"""

import argparse
import bz2
import gzip
import hashlib
import io
import json
import lzma
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
import xml.parsers.expat
from concurrent.futures import ThreadPoolExecutor

PULP_BASE = 'https://build.almalinux.org/pulp/content/prod/'

# Gated repositories per release. Key: repository directory in a published
# tree, value: Pulp repository name without the "-<arch>" suffix.
#   Pulp: <PULP_BASE><value>-<arch>/
#   copy: <root>/<key>/<arch>/os/
GATED = {
    '8': {
        'arches': ['x86_64', 'aarch64'],
        'repos': {
            'BaseOS': 'almalinux-8-baseos',
            'AppStream': 'almalinux-8-appstream',
            'PowerTools': 'almalinux-8-powertools',
            'extras': 'almalinux-8-extras',
        },
    },
    '9': {
        'arches': ['x86_64', 'aarch64'],
        'repos': {
            'BaseOS': 'almalinux-9-baseos',
            'AppStream': 'almalinux-9-appstream',
            'CRB': 'almalinux-9-crb',
            'extras': 'almalinux-9-extras',
        },
    },
    '10': {
        'arches': ['x86_64', 'x86_64_v2', 'aarch64'],
        'repos': {
            'BaseOS': 'almalinux-10-baseos',
            'AppStream': 'almalinux-10-appstream',
            'CRB': 'almalinux-10-crb',
            'extras': 'almalinux-10-extras',
        },
    },
    '10-kitten': {
        'arches': ['x86_64', 'x86_64_v2', 'aarch64'],
        'repos': {
            'BaseOS': 'almalinux-kitten-10-baseos',
            'AppStream': 'almalinux-kitten-10-appstream',
            'CRB': 'almalinux-kitten-10-crb',
            'extras-common': 'almalinux-kitten-10-extras-common',
        },
    },
}

REPO_NS = '{http://linux.duke.edu/metadata/repo}'
TIMEOUT = 300
SOURCES_RE = re.compile(r'^pulp(\+[a-z]+)*$')

with open(__file__, 'rb') as _self:
    # Hash of this very file: digests are comparable only between runs of the same copy.
    ALG = hashlib.sha256(_self.read()).hexdigest()[:8]


def digest(lines):
    return hashlib.sha256('\n'.join(lines).encode()).hexdigest()[:16]


def _read(base, rel):
    """Read base + rel, where base is an http(s) URL or a local directory ending with '/'."""
    if base.startswith(('http://', 'https://')):
        with urllib.request.urlopen(base + rel, timeout=TIMEOUT) as resp:
            return resp.read()
    with open(base + rel, 'rb') as f:
        return f.read()


def _open_metadata(base, href):
    data = io.BytesIO(_read(base, href))
    if href.endswith('.gz'):
        return gzip.GzipFile(fileobj=data)
    if href.endswith('.xz'):
        return lzma.LZMAFile(data)
    if href.endswith('.bz2'):
        return bz2.BZ2File(data)
    if href.endswith('.zst'):
        try:
            from compression import zstd  # Python 3.14+
        except ImportError:
            raise RuntimeError(f'{base}{href}: zstd-compressed metadata needs Python 3.14+')
        return zstd.ZstdFile(data)
    return data


def _repomd(base):
    """{metadata type: location href} of repodata/repomd.xml."""
    root = ET.fromstring(_read(base, 'repodata/repomd.xml'))
    return {d.get('type'): d.find(REPO_NS + 'location').get('href')
            for d in root.findall(REPO_NS + 'data')}


def package_lines(base, href):
    """Sorted '<pkgid>  <name>-<epoch>:<version>-<release>.<arch>' lines of other.xml."""
    lines = []
    declared = []
    current = [None]

    def start(name, attrs):
        if name == 'package':
            current[0] = (attrs['pkgid'], attrs['name'], attrs['arch'])
        elif name == 'version':
            pkgid, pkg_name, arch = current[0]
            lines.append(f"{pkgid}  {pkg_name}-{attrs.get('epoch') or '0'}:{attrs['ver']}-{attrs['rel']}.{arch}")
        elif name == 'otherdata':
            declared.append(attrs.get('packages'))

    parser = xml.parsers.expat.ParserCreate()
    parser.StartElementHandler = start
    parser.ParseFile(_open_metadata(base, href))
    if declared and declared[0] is not None and int(declared[0]) != len(lines):
        raise RuntimeError(f'{base}{href}: declares {declared[0]} packages, parsed {len(lines)}')
    lines.sort()
    return lines


def _str_keys(obj):
    # YAML turns stream names like 1.10 into numbers; keep keys comparable.
    if isinstance(obj, dict):
        return {str(k): _str_keys(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_str_keys(v) for v in obj]
    return obj


def module_lines(base, href):
    """Sorted normalized documents of modules.yaml: NSVCA with artifacts, defaults, the rest as JSON."""
    import yaml
    loader = getattr(yaml, 'CSafeLoader', None)
    if loader is None:
        raise RuntimeError('PyYAML is built without libyaml (no CSafeLoader); install python3-yaml')
    lines = []
    for doc in yaml.load_all(_open_metadata(base, href).read(), Loader=loader):
        if not doc:
            continue
        kind, data = doc.get('document'), _str_keys(doc.get('data') or {})
        if kind == 'modulemd':
            rpms = sorted((data.get('artifacts') or {}).get('rpms') or [])
            nsvca = ':'.join(str(data.get(k)) for k in ('name', 'stream', 'version', 'context', 'arch'))
            lines.append(f"{nsvca} {','.join(rpms)}")
        elif kind == 'modulemd-defaults':
            profiles = json.dumps(data.get('profiles'), sort_keys=True)
            lines.append(f"defaults {data.get('module')}:{data.get('stream')} {profiles}")
        else:
            lines.append(f'{kind} {json.dumps(data, sort_keys=True, default=str)}')
    lines.sort()
    return lines


def unit_lines(base):
    """(package lines, module lines or None) of one repository."""
    md = _repomd(base)
    if 'other' not in md:
        raise RuntimeError(f'{base}: repomd.xml has no other.xml')
    modules = module_lines(base, md['modules']) if 'modules' in md else None
    return package_lines(base, md['other']), modules


def gated_repos(version, arch):
    if version not in GATED:
        raise ValueError(f"unknown version {version!r}, expected one of: {', '.join(GATED)}")
    if arch not in GATED[version]['arches']:
        raise ValueError(f"version {version} is not gated on {arch!r}, only on: {', '.join(GATED[version]['arches'])}")
    return GATED[version]['repos']


def pulp_bases(version, arch, pulp_base=PULP_BASE):
    return {key: f'{pulp_base}{name}-{arch}/' for key, name in gated_repos(version, arch).items()}


def fs_bases(version, arch, root):
    return {key: f"{root.rstrip('/')}/{key}/{arch}/os/" for key in gated_repos(version, arch)}


def state(version, arch, bases, sources=None):
    """The compose-state record: alg, v, arch, r (Pulp only), d and, for modular repositories, m."""
    record = {'alg': ALG, 'v': version, 'arch': arch}
    if sources is not None:
        record['r'] = sources
    with ThreadPoolExecutor(max_workers=len(bases)) as pool:
        units = dict(zip(bases, pool.map(unit_lines, bases.values())))
    record['d'] = {key: digest(packages) for key, (packages, _) in units.items()}
    modules = {key: digest(mods) for key, (_, mods) in units.items() if mods is not None}
    if modules:
        record['m'] = modules
    return record


def main(argv=None):
    ap = argparse.ArgumentParser(description='Digest of the gated repositories of one release and arch.')
    sub = ap.add_subparsers(dest='mode')
    sub.required = True
    pulp = sub.add_parser('pulp', help='digest the Pulp repositories, as tested by compose-tests')
    fs = sub.add_parser('fs', help='digest another copy of the repositories: a local tree or a mirror')
    for p in (pulp, fs):
        p.add_argument('--version', required=True, help=f"release: {', '.join(GATED)}")
        p.add_argument('--arch', required=True, help='basearch, e.g. x86_64, x86_64_v2, aarch64')
    pulp.add_argument('--sources', default='pulp',
                      help='repository sources enabled in the test VM: pulp, pulp+testing, pulp+pungi')
    pulp.add_argument('--pulp-base', default=PULP_BASE, help=f'default: {PULP_BASE}')
    fs.add_argument('--root', required=True,
                    help='release root of the copy, a directory or an http(s) URL, '
                         'e.g. https://repo.almalinux.org/almalinux/10')
    args = ap.parse_args(argv)

    if args.mode == 'pulp' and not SOURCES_RE.match(args.sources):
        ap.error(f'--sources must look like pulp or pulp+testing, got {args.sources!r}')
    try:
        if args.mode == 'pulp':
            record = state(args.version, args.arch, pulp_bases(args.version, args.arch, args.pulp_base), args.sources)
        else:
            record = state(args.version, args.arch, fs_bases(args.version, args.arch, args.root))
    except (ValueError, RuntimeError, OSError, ET.ParseError, xml.parsers.expat.ExpatError) as e:
        print(f'compose_state: {e}', file=sys.stderr)
        return 1
    print(json.dumps(record, separators=(',', ':')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
