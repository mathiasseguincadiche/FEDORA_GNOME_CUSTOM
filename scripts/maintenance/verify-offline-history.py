#!/usr/bin/env python3
"""Require the successful DNF5 history entry belonging to our offline request."""
import argparse
import json
import re
import sys
import shlex


def verify(rows, comment, not_before):
    if not re.fullmatch(r'fgc-offline-[0-9a-f-]{36}', comment):
        raise ValueError('invalid project transaction identity')
    if not isinstance(rows, list):
        raise ValueError('history must be a JSON array')
    # DNF5 offline execute preserves the original command in description,
    # but does not populate history.comment. Match a complete argument, never
    # a substring or a previous offline journal entry.
    def belongs(row):
        args = shlex.split(row.get('description', ''))
        return (args.count('--comment=' + comment) == 1 and
                'upgrade' in args and '--offline' in args)
    matches = [row for row in rows if belongs(row)]
    if len(matches) != 1:
        raise ValueError('no unique history entry for the prepared offline transaction')
    row = matches[0]
    if row.get('status') != 'Ok':
        raise ValueError('offline transaction did not complete successfully')
    for key in ('id', 'start_time', 'end_time'):
        if type(row.get(key)) is not int:
            raise ValueError('incomplete transaction history')
    if not (row['id'] > 0 and row['end_time'] >= row['start_time'] >= not_before):
        raise ValueError('history entry predates preparation or is incomplete')
    return row['id']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('comment')
    parser.add_argument('not_before', type=int)
    args = parser.parse_args()
    try:
        print(verify(json.load(sys.stdin), args.comment, args.not_before))
    except (ValueError, TypeError, AttributeError, KeyError) as error:
        parser.exit(1, 'Offline completion refused: ' + str(error) + '\n')
