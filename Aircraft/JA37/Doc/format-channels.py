#!/usr/bin/python3

import re
import sys
import argparse


## Input

# Regexes for various channel types
special_channel = re.compile(r"S[1-3]|[E-GML]")
group_channel = re.compile(r"N[0-9]{2,3}")
airbase_channel = re.compile(r"B[0-9]{3}(?:[A-D]|C2)?")

channels_table = {}
has_special = False
has_group = False
has_airbase = False

def channel(key):
    return channels_table.get(key, "")


def parse_line(line, error_prefix):
    tokens = line.split('#', maxsplit=1)[0].split(maxsplit=1)
    if len(tokens) == 0:
        return

    global has_special, has_group, has_airbase

    if special_channel.match(tokens[0]):
        has_special = True
    elif group_channel.match(tokens[0]):
        has_group = True
    elif airbase_channel.match(tokens[0]):
        has_airbase = True
    else:
        print("{}Ignoring unexpected identifier: {}".format(error_prefix, tokens[0]),
              file=sys.stderr)
        return

    channels_table[tokens[0]] = tokens[1].strip()


def read_input(file):
    for line_no, line in enumerate(file):
        parse_line(line, "{}:l{}: ".format(file.name, line_no))


## Output

general_channels = ["E", "F", "G", "M", "L", "S1", "S2", "S3"]

general_format=r"""
\begin{{tabular}}{{ccccc}}
  H & E & F & G \\
  \hline
  121.500 & {E} & {F} & {G} \\[1ex]
  M & L & S1 & S2 & S3 \\
  \hline
  {M} & {L} & {S1} & {S2} & {S3}
\end{{tabular}}
"""

def print_general(file):
    channels = { c: channel(c) for c in general_channels }
    print(general_format.format_map(channels), file=file)


def print_group(code, file):
    description = channel("N{}".format(code))
    channels = [channel("N{}{}".format(code, c)) for c in range(10)]

    if not any(channels):
        return

    file.write("  {} & {}".format(code, description))
    for freq in channels[:5]:
        file.write(" & {}".format(freq))
    file.write(" \\\\\n  &")
    for freq in channels[5:]:
        file.write(" & {}".format(freq))
    file.write(" \\\\\n")

group_preamble = r"""
\begin{longtable}{rlccccc}
  & Group & 0/5 & 1/6 & 2/7 & 3/8 & 4/9 \\
  \hline"""

def print_groups(file):
    print(r"\rowcolors{3}{lightgray}{}", file=file)
    print(group_preamble, file=file)

    for code in range(43):
        print_group("{:02d}".format(code), file)

    print("\\end{longtable}\n", file=file)


base_channels = ["A", "B", "C", "C2", "D"]

def print_airbase(code, file):
    description = channel("B{}".format(code))
    channels = [channel("B{}{}".format(code, c)) for c in base_channels]

    if not any(channels):
        return

    file.write("  {} & {}".format(code, description))
    for freq in channels:
        file.write(" & {}".format(freq))
    file.write(" \\\\\n")

airbase_preamble = r"""
\begin{longtable}{rlccccc}
  & Airbase & A & B & C & C2 & D \\
  \hline"""

def print_airbases(file):
    print(r"\pagebreak[3]", file=file)  # strong hint to break the page here
    print(r"\rowcolors{3}{lightgray}{}", file=file)

    print(airbase_preamble, file=file)

    for code in range(170):
        print_airbase("{:03d}".format(code), file)

    print("\\end{longtable}\n", file=file)


latex_preamble = r"""\documentclass[a4paper,11pt]{article}

\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{geometry}
\usepackage[table]{xcolor}
\usepackage{longtable}

\pagestyle{myheadings}

\begin{document}"""

def print_channels(file, title, special, groups, airbases):
    print(latex_preamble, file=file)
    print(r"\markright{{\textup{{{}}}}}".format(title), file=file)

    if special:
        print_general(file)

    if groups:
        print_groups(file)

    if airbases:
        print_airbases(file)

    print(r"\end{document}", file=file)



## Options

parser = argparse.ArgumentParser(
        description="Format Saab 37 Viggen radio configuration files as LaTeX tables.")


parser.add_argument('input', nargs='?', type=argparse.FileType("r"), default=sys.stdin,
                    help="input radio configuration file (default: standard input)")
parser.add_argument('output', nargs='?', type=argparse.FileType("w"),
                    help="output LaTeX file (default from input file name)")
parser.add_argument("-t", "--title",
                    help="title displayed in the output file (default from input file name)")
parser.add_argument("-a", "--airbases", action="store_true",
                    help="format airbase channels, can be combined with -g, -s (default: all)")
parser.add_argument("-g", "--groups", action="store_true",
                    help="format group channels, can be combined with -a, -s (default: all)")
parser.add_argument("-s", "--special", action="store_true",
                    help="format special channels, can be combined with -a, -g (default: all)")


if __name__ == "__main__":
    args = parser.parse_args()

    # If none of -a,-g,-s specified, print everything.
    if not args.airbases and not args.groups and not args.special:
        args.airbases = args.groups = args.special = True

    if args.output is None:
        if args.input == sys.stdin:
            args.output = sys.stdout
        else:
            args.output = open(args.input.name.removesuffix(".txt") + ".tex", "w")

    if args.title is None:
        if args.input == sys.stdin:
            args.title = "Comm channels"
        else:
            args.title = args.input.name.removesuffix(".txt")

    read_input(args.input)
    print_channels(args.output, args.title,
                   args.special and has_special,
                   args.groups and has_group,
                   args.airbases and has_airbase)

    if args.output != sys.stdout:
        print("Channels written to {file}. To compile to pdf, run\n$ pdflatex {file}"
              .format(file=args.output.name))
