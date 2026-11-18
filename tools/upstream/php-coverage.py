"""Render declared PHP extension coverage and source-backed compatibility limits."""
import json
import re
import sys
from collections import defaultdict


def version_key(version):
    return [int(part) for part in re.findall(r'\d+', version)]


def php_summary(rows):
    groups = defaultdict(set)
    for row in rows:
        groups['.'.join(row['php'].split('.')[:2])].add(row['php'])
    return ', '.join(
        next(iter(versions)) if len(versions) == 1 else f'{minor} ({len(versions)} versions)'
        for minor, versions in sorted(groups.items(), key=lambda item: version_key(item[0]))
    )


def render(coverage, selector=None):
    if selector is not None and not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', selector):
        raise ValueError('PHP selector must be a major, minor, or complete version')
    if not isinstance(coverage, dict) or coverage.get('kind') not in ('independent', 'bundled'):
        raise ValueError('expected independent or bundled PHP coverage')
    rows = coverage.get('rows')
    if not isinstance(rows, list):
        raise ValueError('PHP coverage rows must be a list')
    seen = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError('PHP coverage row must be an object')
        if not isinstance(row.get('php'), str) or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){2}', row['php']):
            raise ValueError('PHP coverage row needs a complete PHP version')
        if not isinstance(row.get('release'), str) or not row['release']:
            raise ValueError('PHP coverage row needs an extension release')
        if row.get('state') not in ('packaged', 'gap', 'incompatible'):
            raise ValueError('unknown PHP coverage state')
        for field in ('reason', 'source'):
            value = row.get(field)
            if value is not None and (not isinstance(value, str) or not value.strip()):
                raise ValueError(f'PHP coverage {field} must be a nonempty string')
            if row['state'] == 'incompatible' and value is None:
                raise ValueError(f'hard compatibility limit needs {field}')
        pair = row['php'], row['release']
        if pair in seen:
            raise ValueError('duplicate PHP and extension release pair')
        seen.add(pair)
    if selector is not None:
        rows = [row for row in rows if row['php'] == selector or row['php'].startswith(selector + '.')]
        if not rows:
            raise ValueError('no declared PHP version matches ' + selector)

    releases = defaultdict(list)
    for row in rows:
        release = 'bundled releases matching PHP' if coverage['kind'] == 'bundled' else 'release ' + row['release']
        releases[release].append(row)
    lines = ['  PHP coverage (declared):']
    if not releases:
        lines.append('    no PHP versions declared')
    for release, release_rows in sorted(releases.items(), key=lambda item: version_key(item[0])):
        lines.append('    ' + release)
        for state, label in (('packaged', 'packaged'), ('gap', 'packaging gaps'), ('incompatible', 'hard limits')):
            matches = [row for row in release_rows if row['state'] == state]
            if not matches:
                lines.append(f'      {label}: none')
            elif state == 'packaged':
                lines.append(f'      {label} ({len(matches)}): ' + php_summary(matches))
            else:
                lines.append(f'      {label} ({len(matches)}):')
                reasons = defaultdict(list)
                for row in matches:
                    reasons[row.get('reason'), row.get('source')].append(row)
                for (reason, source), group in reasons.items():
                    lines.append('        ' + php_summary(group))
                    if reason:
                        lines.append('          why: ' + reason)
                    if source:
                        lines.append('          source: ' + source)
    return '\n'.join(lines)


def main():
    try:
        if len(sys.argv) not in (2, 3):
            raise ValueError('expected COVERAGE_JSON and optional PHP selector')
        data = json.load(sys.stdin) if sys.argv[1] == '-' else json.loads(sys.argv[1])
        print(render(data, sys.argv[2] if len(sys.argv) == 3 else None))
    except (ValueError, TypeError) as error:
        print('tvp-upstream: invalid PHP coverage: ' + str(error), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
