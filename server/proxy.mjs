// PixelWhisper -> PixelLab proxy.
//
// WHY: the PixelLab API token must never ship inside the game (APK/Web builds can be
// unpacked in minutes, and anyone could then spend your generations). The game talks to
// THIS server instead; the server holds the token, limits abuse and forwards only the
// two calls the game needs.
//
//   PIXELLAB_API_TOKEN=...  node server/proxy.mjs
//   then in project.godot:  [pixellab] base_url="https://your-host/v2"
//
// Zero dependencies (Node 18+). Deploy anywhere (Railway: set the PIXELLAB_API_TOKEN
// variable, start command `node server/proxy.mjs`; it listens on $PORT).
//
// Environment:
//   PIXELLAB_API_TOKEN  (required)  your PixelLab token
//   PIXELLAB_UPSTREAM   default https://api.pixellab.ai/v2  (point at the mock to test)
//   ALLOWED_ORIGINS     comma list for CORS, default "*" (set your web domain in production)
//   RATE_PER_HOUR       generations per client IP per hour, default 6
//   MAX_PROMPT_CHARS    default 220
//   PORT                default 8788

import http from "node:http";

const TOKEN = process.env.PIXELLAB_API_TOKEN;
const UPSTREAM = (process.env.PIXELLAB_UPSTREAM || "https://api.pixellab.ai/v2").replace(/\/$/, "");
const ORIGINS = (process.env.ALLOWED_ORIGINS || "*").split(",").map((s) => s.trim());
const RATE = Number(process.env.RATE_PER_HOUR || 6);
const MAX_PROMPT = Number(process.env.MAX_PROMPT_CHARS || 220);
const PORT = Number(process.env.PORT || 8788);

if (!TOKEN) {
  console.error("PIXELLAB_API_TOKEN is not set");
  process.exit(1);
}

// Everything below is forced server-side: a modified client can only choose the prompt.
const FIXED = {
  image_size: { width: 64, height: 64 },
  no_background: false,
  detail: "medium detail",
  shading: "basic shading",
  outline: "selective outline",
};

const hits = new Map(); // ip -> [timestamps]
const jobOwner = new Map(); // job id -> ip (a client may only poll its own jobs)

function allowed(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 3_600_000);
  if (recent.length >= RATE) return false;
  recent.push(now);
  hits.set(ip, recent);
  return true;
}

function cors(req, res) {
  const origin = req.headers.origin || "";
  const ok = ORIGINS.includes("*") || ORIGINS.includes(origin);
  if (ok) res.setHeader("Access-Control-Allow-Origin", ORIGINS.includes("*") ? "*" : origin);
  res.setHeader("Access-Control-Allow-Headers", "content-type");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS");
}

function send(res, code, body) {
  res.writeHead(code, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

async function readJson(req, limit = 8192) {
  let size = 0;
  const chunks = [];
  for await (const c of req) {
    size += c.length;
    if (size > limit) throw new Error("body too large");
    chunks.push(c);
  }
  return JSON.parse(Buffer.concat(chunks).toString() || "{}");
}

async function upstream(method, path, body) {
  const r = await fetch(UPSTREAM + path, {
    method,
    headers: { authorization: `Bearer ${TOKEN}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = {};
  try { json = await r.json(); } catch { /* empty body */ }
  return { status: r.status, json };
}

const server = http.createServer(async (req, res) => {
  cors(req, res);
  if (req.method === "OPTIONS") return send(res, 204, {});
  const ip = (req.headers["x-forwarded-for"] || req.socket.remoteAddress || "?").toString().split(",")[0].trim();
  const url = new URL(req.url, "http://x");
  const path = url.pathname.replace(/^\/v2/, "");

  try {
    if (req.method === "GET" && path === "/health") return send(res, 200, { ok: true });

    if (req.method === "POST" && path === "/create-image-pixflux-background") {
      const body = await readJson(req);
      const description = String(body.description || "").trim();
      if (!description) return send(res, 422, { detail: "description is required" });
      if (description.length > MAX_PROMPT) return send(res, 422, { detail: "description too long" });
      if (!allowed(ip)) return send(res, 429, { detail: "rate limit: try again later" });
      const out = await upstream("POST", "/create-image-pixflux-background", {
        description,
        negative_description: String(body.negative_description || "").slice(0, 200),
        ...FIXED,
      });
      if (out.status === 202 && out.json.background_job_id) jobOwner.set(out.json.background_job_id, ip);
      // Never leak upstream account details (usage/balance) to clients.
      delete out.json.usage;
      return send(res, out.status, out.json);
    }

    const m = path.match(/^\/background-jobs\/([\w-]+)$/);
    if (m && (req.method === "GET" || req.method === "DELETE")) {
      if (jobOwner.get(m[1]) !== ip) return send(res, 404, { detail: "Job not found" });
      const out = await upstream(req.method, `/background-jobs/${m[1]}`);
      delete out.json.usage;
      return send(res, out.status, out.json);
    }

    send(res, 404, { detail: "not found" });
  } catch (e) {
    console.error(e);
    send(res, 502, { detail: "upstream error" });
  }
});

server.listen(PORT, () => console.log(`PixelWhisper proxy on :${PORT} -> ${UPSTREAM}`));
