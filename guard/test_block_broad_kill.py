#!/usr/bin/env python3
"""block-broad-kill.py 的用例。运行：python3 guard/test_block_broad_kill.py

危险命令按片段拼接：整段写在字面里的话，在装了本 hook 的会话里连跑测试都会被拦。
"""
import json, os, subprocess, sys, unittest

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "block-broad-kill.py")
S, B = "$(", "`"
K = "ki" + "ll"
PK, KA, PG = "p" + K, K + "all", "pgrep"

DENY = [
    f'{PK} -f "cat" -n 2>/dev/null; ls',
    f"sudo {PK} -9f node",
    f"/usr/bin/{PK} -lf vite",
    f"{PK} --full foo",
    f"{KA} Dock",
    f"echo hi && {KA} -9 node",
    f"cd x; FOO=1 {KA} node",
    f"{K} {S}{PG} -f cat)",
    f'{K} -9 {S}{PG} -lf "node server")',
    f"{K} {B}{PG} -f vite{B}",
    f"sudo {K} {S}/usr/bin/{PG} --full x)",
    f"{PG} -f vite | xargs {K} -9",
    f"{PG} -f vite | sudo xargs {K}",
]
ALLOW = [
    f"{K} 12345",
    f"{PK} vite",
    f"{PG} -fl vite",
    f"{PG} -f vite | head",
    f"{K} {S}{PG} vite)",
    f"{K} {S}cat app.pid)",
    f"{K} {S}lsof -ti :3000)",
    "ls -f",
    f"grep -r {KA}_count src",
    "npm run dev",
]


def decide(cmd):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd}})
    out = subprocess.run([sys.executable, HOOK], input=payload,
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else "allow"


class BlockBroadKill(unittest.TestCase):
    def test_deny(self):
        for cmd in DENY:
            with self.subTest(cmd=cmd):
                self.assertEqual(decide(cmd), "deny")

    def test_allow(self):
        for cmd in ALLOW:
            with self.subTest(cmd=cmd):
                self.assertEqual(decide(cmd), "allow")

    def test_bad_input_passes(self):
        r = subprocess.run([sys.executable, HOOK], input="not json",
                           capture_output=True, text=True)
        self.assertEqual((r.returncode, r.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
