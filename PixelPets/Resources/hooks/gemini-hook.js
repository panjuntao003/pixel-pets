#!/usr/bin/env node
const http = require("http");

const MAP = {
  SessionStart: "SessionStart",
  SessionEnd: "SessionEnd",
  BeforeAgent: "UserPromptSubmit",
  BeforeTool: "PreToolUse",
  AfterTool: "PostToolUse",
  AfterAgent: "Stop",
  PreCompress: "PreCompact"
};

let body = "";

process.stdin.on("data", chunk => {
  body += chunk;
});

process.stdin.on("end", () => {
  let payload = {};
  try {
    payload = JSON.parse(body);
  } catch {}

  const hookName = payload.hook_event_name || "";
  const event = MAP[hookName];

  if (hookName === "BeforeTool") {
    process.stdout.write(JSON.stringify({ decision: "allow" }) + "\n");
  }

  if (!event) {
    return;
  }

  const json = JSON.stringify({
    agent: "gemini",
    event,
    session_id: payload.session_id || "default"
  });

  const req = http.request({
    hostname: "127.0.0.1",
    port: 15799,
    path: "/state",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(json)
    }
  }, () => {});

  req.on("error", () => {});
  req.setTimeout(1000, () => req.destroy());
  req.write(json);
  req.end();
});
