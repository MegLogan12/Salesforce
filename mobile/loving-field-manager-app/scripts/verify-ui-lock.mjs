import fs from "node:fs";
import crypto from "node:crypto";

const expected = "bd0aa4997d2b00da9bfeeee204356f76ac8791decf50d62371bbfeed5dee5e9b";
const css = fs.readFileSync("src/styles/field-manager.css", "utf8");
const actual = crypto.createHash("sha256").update(css).digest("hex");

if (actual !== expected) {
  console.error("UI lock failed: src/styles/field-manager.css changed.");
  console.error(`Expected ${expected} but received ${actual}.`);
  console.error("Do not edit the visual CSS unless Meg explicitly approves a visual change.");
  process.exit(1);
}
console.log("UI lock passed. Frozen CSS matches the uploaded visual source.");
