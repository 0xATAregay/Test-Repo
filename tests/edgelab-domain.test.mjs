import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const domain=fs.readFileSync(new URL("../app/domain.ts",import.meta.url),"utf8");
const seed=fs.readFileSync(new URL("../app/seed.ts",import.meta.url),"utf8");
const ui=fs.readFileSync(new URL("../app/edgelab.tsx",import.meta.url),"utf8");
const schema=fs.readFileSync(new URL("../db/schema.ts",import.meta.url),"utf8");

test("XP ledger implements duplicate-key guard",()=>{assert.match(domain,/events\.some\(e=>e\.key===key\)\?events/);assert.match(schema,/xp_event_user_key_uidx/)});
test("playbook revision is append-only and requires reason",()=>{assert.match(domain,/meaningful revision reason is required/);assert.match(domain,/versions:\[\.\.\.p\.versions/);assert.match(schema,/playbook_version_uidx/)});
test("process scoring separates rubric from future price outcome",()=>{const scoring=domain.slice(domain.indexOf("export function scoreProcess"),domain.indexOf("export function revisePlaybook"));assert.match(scoring,/classification===c\.expected/);assert.doesNotMatch(scoring,/bars|profit|pnl|movement/)});
test("sample-size warnings cover small and developing samples",()=>{assert.match(domain,/Small sample/);assert.match(domain,/Developing sample/)});
test("import validates EdgeLab identity and schema",()=>{assert.match(domain,/x\?\.app!==\"EdgeLab\"/);assert.match(domain,/schemaVersion:2/)});
test("Comeback Mode threshold exists and UI hides ordinary missions",()=>{assert.match(domain,/4\*86400000/);assert.match(ui,/Comeback Mode/);assert.match(ui,/10-minute re-entry/)});
test("adaptive drill selection prioritizes weak context",()=>{assert.match(domain,/mistakes=decisions\.filter\(d=>d\.score<75\)/);assert.match(domain,/c\.context===cases\.find/)});
test("weekly aggregation calculates process and false-positive evidence",()=>{assert.match(domain,/falsePositiveRate/);assert.match(domain,/correctUnclear/)});
test("seed contains 24 weeks, 48 lessons by construction, and 48 deterministic cases",()=>{assert.match(seed,/length:24/);assert.match(seed,/flatMap\(w=>\[lesson/);assert.match(seed,/length:48/);assert.match(seed,/bars\(101\+i\*37/)});
test("UI exposes all ten required primary areas",()=>{for(const name of ["Today","Roadmap","Academy","Analysis Lab","Playbook","Journal","Weekly Review","Analytics","Evidence Library","Settings"])assert.ok(ui.includes(`\"${name}\"`),name)});
test("education-only boundaries are visible in product UI",()=>{assert.match(ui,/Educational exercise only/);assert.match(ui,/No order execution/);assert.match(ui,/Six months is a checkpoint/)});
