#!/usr/bin/env python3

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


# We read each comma-separated score trajectory and standardize its length for
# comparison across molecular growth histories.

def read_score_strings(filename, max_segments=11):

    series = []

    with open(filename, "r") as handle:

        for line in handle:

            line = line.strip()

            if not line:
                continue

            values = [
                float(value)
                for value in line.split(",")
                if value.strip()
            ]

            values = values[:max_segments]

            # Shorter growth trajectories are padded with NaN so they can be
            # plotted on the same segment axis without introducing score values.

            if len(values) < max_segments:
                values.extend(
                    [np.nan] * (max_segments - len(values))
                )

            series.append(
                np.asarray(values, dtype=float)
            )

    return series


def main():

    # We define the static-reference and Dynamic Reference score-string inputs,
    # the maximum number of growth segments, and the output figure.

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--static",
        default="scorestrs.csv",
    )

    parser.add_argument(
        "--dynamic",
        default="scorestrs_dyn.csv",
    )

    parser.add_argument(
        "--segments",
        type=int,
        default=11,
    )

    parser.add_argument(
        "--output",
        default="score_strings.png",
    )

    args = parser.parse_args()

    x = np.arange(1, args.segments + 1)

    static_file = Path(args.static)
    dynamic_file = Path(args.dynamic)

    # We plot the static-reference score trajectories when the corresponding
    # input file is available.

    if static_file.is_file():

        for values in read_score_strings(
            static_file,
            args.segments,
        ):
            plt.plot(
                x,
                values,
                linestyle="solid",
                color="red",
                alpha=0.5,
            )

    # We plot the Dynamic Reference trajectories on the same axes for direct
    # comparison with the static-reference trajectories.

    if dynamic_file.is_file():

        for values in read_score_strings(
            dynamic_file,
            args.segments,
        ):
            plt.plot(
                x,
                values,
                linestyle="solid",
                color="green",
                alpha=0.5,
            )

    # We label the molecular growth and Descriptor Score axes and save the
    # comparison figure at publication-quality resolution.

    plt.xlabel("Added Segments")
    plt.ylabel("Score: 25*HMS + 1*GRD")
    plt.tight_layout()
    plt.savefig(
        args.output,
        dpi=300,
    )


if __name__ == "__main__":
    main()
