// check-lua.mjs — parse every .lua file under MountRoadmap/ with luaparse to
// catch syntax errors (WoW uses a Lua 5.1 dialect).
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import luaparse from 'luaparse';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIR = join(__dirname, '..', 'MountRoadmap');

const files = readdirSync(DIR).filter((f) => f.endsWith('.lua'));
let failures = 0;
for (const f of files) {
  const src = readFileSync(join(DIR, f), 'utf8');
  try {
    luaparse.parse(src, { luaVersion: '5.1' });
    console.log(`OK   ${f}`);
  } catch (e) {
    failures++;
    console.log(`FAIL ${f}: ${e.message}`);
  }
}
console.log(failures ? `\n${failures} file(s) failed.` : `\nAll ${files.length} files parsed OK.`);
process.exit(failures ? 1 : 0);
