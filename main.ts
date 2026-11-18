// main.ts
// The entrypoint for Brainrot Bazaar (roblox-brainrot-01). A Node 22
// program, standard library only. It hands the game in: it copies
// game.rbxl, PLAY.json, src/ and screenshots/ from beside itself to
// /output (or $MAKEFUN_OUTPUT_DIR when set) and writes
// /output/dossier.json with the vendored library's dossier builder.
//
// Nothing whose name starts with a dot (.gitkeep, .DS_Store, .git)
// is ever copied, at any depth -- the grader fails an entry whose
// output holds one.
//
// Run it as the grader does, writing out/ in place of /output:
//
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = process.env.MAKEFUN_OUTPUT_DIR
	? resolve(process.env.MAKEFUN_OUTPUT_DIR)
	: "/output";

// A name is copyable when it does not start with a dot. The grader
// refuses any dot-named file or directory under /output.
function copyable(name: string): boolean {
	return !name.startsWith(".");
}

function copyTree(srcDir: string, destDir: string): void {
	mkdirSync(destDir, { recursive: true });
	for (const entry of readdirSync(srcDir)) {
		if (!copyable(entry)) {
			continue;
		}
		const src = join(srcDir, entry);
		const dest = join(destDir, entry);
		if (statSync(src).isDirectory()) {
			copyTree(src, dest);
		} else {
			copyFileSync(src, dest);
		}
	}
}

function copyFile(name: string): void {
	const src = join(HERE, name);
	if (!copyable(name)) {
		return;
	}
	copyFileSync(src, join(OUT, name));
}

mkdirSync(OUT, { recursive: true });

copyFile("game.rbxl");
copyFile("PLAY.json");
copyTree(join(HERE, "src"), join(OUT, "src"));
copyTree(join(HERE, "screenshots"), join(OUT, "screenshots"));

writeFileSync(
	join(OUT, "dossier.json"),
	buildDossier(OUT, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);

console.log("Brainrot Bazaar handed in to " + OUT);
