// Brainrot Bazaar — the entrypoint for roblox-brainrot-01 (Node 22, stdlib only).
// It hands the game in: game.rbxl, PLAY.json, src/ and screenshots/ are copied
// from beside this file into /output (or $MAKEFUN_OUTPUT_DIR when set), and
// /output/dossier.json is written with the kit's vendored library. The copy
// leaves out every file or directory whose name starts with a dot, at any
// depth — the grader refuses an entry whose output holds one (.gitkeep,
// .DS_Store, .git). It runs twice in the grader and must write the same
// bytes both times, so there is no timestamp or randomness anywhere here.
//
// Run it the way the grader does, writing out/ in place of /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

// The repository root is the directory this file sits in.
const root = fileURLToPath(new URL('.', import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** True for every path cpSync may copy: nothing whose name starts with a dot. */
function keepEntry(path: string): boolean {
	return !basename(path).startsWith('.');
}

/** Copy one directory tree, skipping dotted names at any depth. */
function copyTree(from: string, to: string): void {
	cpSync(from, to, { recursive: true, filter: keepEntry });
}

// The place and the play link go in as single files.
copyFileSync(join(root, 'game.rbxl'), join(outDir, 'game.rbxl'));
copyFileSync(join(root, 'PLAY.json'), join(outDir, 'PLAY.json'));

// The source tree and the screenshots go in as trees.
copyTree(join(root, 'src'), join(outDir, 'src'));
mkdirSync(join(outDir, 'screenshots'), { recursive: true });
if (existsSync(join(root, 'screenshots'))) {
	copyTree(join(root, 'screenshots'), join(outDir, 'screenshots'));
}

// The dossier: the judge's summary, written by the kit's own library from
// exactly what was just copied, under the scorer's caps (reference/gate.json).
// Only text_max_bytes shapes the bytes; the other caps refuse an entry the
// scorer would refuse anyway (more than 4 screenshots or one over 256 KiB;
// a place over 500000 instances; scripts over 8 MiB of source in all, or
// over 1048576 path characters in all).
const dossier = buildDossier(outDir, {
	text_max_bytes: 65536,
	screenshots: { max: 4, max_bytes: 262144 },
	max_instances: 500000,
	scripts_max_source_bytes: 8388608,
	scripts_max_path_chars: 1048576,
});
writeFileSync(join(outDir, 'dossier.json'), dossier);
