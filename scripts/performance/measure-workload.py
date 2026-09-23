#!/usr/bin/env python3
"""Repeated wall-clock measurements with raw logs; no automatic performance claim."""
import datetime
import json
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time


def measure(output, label, repetitions, commit, config, fingerprint, command):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    result = dict(schema=1, label=label, commit=commit, effective_config_sha256=config,
                  runtime_fingerprint=fingerprint, kernel=platform.release(),
                  utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  command=command, repetitions=repetitions, samples=[], verdict='FAIL')
    rc = 1
    try:
        for index in range(repetitions):
            with (output / f'run-{index + 1:02d}.log').open('wb') as log:
                start = time.perf_counter_ns()
                run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False)
                seconds = (time.perf_counter_ns() - start) / 1e9
            result['samples'].append(dict(seconds=seconds, exit_code=run.returncode))
            if run.returncode:
                return 1
        timings = [sample['seconds'] for sample in result['samples']]
        result.update(verdict='PASS', median_seconds=statistics.median(timings),
                      min_seconds=min(timings), max_seconds=max(timings),
                      stdev_seconds=statistics.stdev(timings) if len(timings) > 1 else 0.)
        rc = 0
    finally:
        (output / 'measurements.json').write_text(json.dumps(result, indent=2) + '\n')
        print(output / 'measurements.json')
    return rc


if __name__ == '__main__':
    output, label, repetitions, commit, config, fingerprint, *command = sys.argv[1:]
    sys.exit(measure(output, label, int(repetitions), commit, config, fingerprint, command))
