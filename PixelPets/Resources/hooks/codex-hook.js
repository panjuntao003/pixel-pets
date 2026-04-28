#!/usr/bin/env node
const http = require("http");

const MAP = {
  SessionStart: "SessionStart",
  UserPromptSubmit: "UserPromptSubmit",
  PreToolUse: "PreToolUse",
  PostToolUse: "PostToolUse",
  Stop: "Stop"
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

  const event = MAP[process.argv[2]];
  if (!event) {
    return;
  }

  const json = JSON.stringify({
    event,
    session_id: payload.session_id || "default",
    tool_name: payload.tool_name
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
  req.setTimeout(100, () => req.destroy());
  req.write(json);
  req.end();
});
