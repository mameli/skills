#!/usr/bin/env python3
"""Count how often each agent skill is used, from local transcripts.

Sources:
- Claude Code: ~/.claude/projects/**/*.jsonl (Skill tool calls, /slash commands,
  Read/Bash calls that open a skills/<name>/SKILL.md file).
- Codex: ~/.codex/sessions and ~/.codex/archived_sessions (tool calls that open
  a skills/<name>/SKILL.md file).

Installed skills come from ~/.agents/skills and ~/.claude/skills; their source
comes from ~/.agents/.skill-lock.json (written by `npx skills`).
"""

import argparse
import collections
import datetime as dt
import glob
import json
import os
import re

HOME = os.path.expanduser("~")
RX_READ = re.compile(r"skills/([A-Za-z0-9_.:-]+)/SKILL\.md")
RX_CMD = re.compile(r"<command-name>/?([^<\s]+)</command-name>")


def installed_skills():
    names = set()
    for root in (f"{HOME}/.agents/skills", f"{HOME}/.claude/skills"):
        if os.path.isdir(root):
            for name in os.listdir(root):
                if os.path.isfile(os.path.join(root, name, "SKILL.md")):
                    names.add(name)
    try:
        with open(f"{HOME}/.agents/.skill-lock.json") as fh:
            lock = json.load(fh).get("skills", {})
    except (OSError, ValueError):
        lock = {}
    return names, lock


class Usage:
    def __init__(self, since):
        self.since = since
        self.counts = {k: collections.Counter() for k in ("skill", "cmd", "read")}
        self.sessions = collections.defaultdict(set)
        self.last = {}

    def note(self, kind, name, session, ts):
        if self.since and ts and ts < self.since:
            return
        name = name.split(":")[-1]
        self.counts[kind][name] += 1
        self.sessions[name].add(session)
        if ts and ts > self.last.get(name, ""):
            self.last[name] = ts


def scan_claude(usage):
    files = glob.glob(f"{HOME}/.claude/projects/**/*.jsonl", recursive=True)
    for path in files:
        session = os.path.basename(path)
        with open(path, errors="ignore") as fh:
            for line in fh:
                if '"Skill"' not in line and "command-name" not in line and "SKILL.md" not in line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                ts = obj.get("timestamp", "")
                content = (obj.get("message") or {}).get("content")
                if obj.get("type") == "assistant" and isinstance(content, list):
                    for block in content:
                        if block.get("type") != "tool_use":
                            continue
                        if block.get("name") == "Skill":
                            usage.note("skill", block.get("input", {}).get("skill", "?"), session, ts)
                        elif block.get("name") in ("Read", "Bash"):
                            for name in set(RX_READ.findall(json.dumps(block.get("input")))):
                                usage.note("read", name, session, ts)
                elif obj.get("type") == "user":
                    text = content if isinstance(content, str) else json.dumps(content)
                    for name in set(RX_CMD.findall(text)):
                        usage.note("cmd", name, session, ts)
    return len(files)


def scan_codex(usage):
    files = []
    for root in ("sessions", "archived_sessions"):
        files += glob.glob(f"{HOME}/.codex/{root}/**/*.jsonl", recursive=True)
    for path in files:
        session = os.path.basename(path)
        with open(path, errors="ignore") as fh:
            for line in fh:
                if "SKILL.md" not in line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                payload = obj.get("payload") or {}
                if payload.get("type") in ("function_call", "custom_tool_call", "local_shell_call"):
                    for name in set(RX_READ.findall(json.dumps(payload))):
                        usage.note("read", name, session, obj.get("timestamp", ""))
    return len(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, help="only count the last N days")
    parser.add_argument("--installed", action="store_true", help="only list installed skills")
    args = parser.parse_args()

    since = ""
    if args.days:
        since = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=args.days)).strftime("%Y-%m-%dT%H:%M:%S")

    usage = Usage(since)
    n_claude = scan_claude(usage)
    n_codex = scan_codex(usage)
    installed, lock = installed_skills()

    names = set(installed)
    if not args.installed:
        for counter in usage.counts.values():
            names |= set(counter)

    rows = sorted(names, key=lambda n: (-len(usage.sessions[n]), n))
    print(f"Transcripts: Claude Code {n_claude}, Codex {n_codex}" + (f", last {args.days} days" if args.days else ""))
    print(f"{'skill':36} {'sess':>4} {'Skill':>5} {'/cmd':>5} {'read':>5}  {'last use':10}  inst  source  installed")
    for name in rows:
        entry = lock.get(name, {})
        print(
            f"{name:36} {len(usage.sessions[name]):4} {usage.counts['skill'][name]:5} "
            f"{usage.counts['cmd'][name]:5} {usage.counts['read'][name]:5}  "
            f"{usage.last.get(name, '')[:10]:10}  {'yes ' if name in installed else '    '}  "
            f"{entry.get('source', '-') if name in installed else ''}  {entry.get('installedAt', '')[:10]}"
        )


if __name__ == "__main__":
    main()
