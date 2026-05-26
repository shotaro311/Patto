import fs from "node:fs/promises";
import path from "node:path";
import {
  DEFAULT_MODEL,
  extensionFromMime,
  generateByGemini,
  readInlineImage,
  resolveApiKey,
  sidecarPathFromImagePath,
  writeBase64Image,
  writeJson,
} from "/Users/shotaro/.codex/plugins/cache/shotaro-local/nanobanana-thumbnail-studio/0.1.0/scripts/nanobanana_core.mjs";

const outputDir =
  "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2_variants_contrast";

const variants = [
  {
    slot: "02_fast_memo_centered_p_contrast",
    referenceImagePath:
      "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2_variants/02_fast_memo_centered_p_01.jpg",
    prompt: [
      "Use the attached app icon as the reference and keep the exact same composition.",
      "Do not redesign the icon. Keep the same mint rounded-square background, the same memo card angle, the same three speed lines, and the same large centered P.",
      "Create a slightly higher-contrast version.",
      "Make the P more legible with a clearer embossed depth, slightly deeper shadows, and a touch more separation from the memo paper.",
      "Make the memo edge, fold corner, and speed lines a little clearer as well.",
      "Keep it elegant, soft, Apple-like, and premium. Do not make it harsh or noisy.",
      "No new text, no purple, no extra elements.",
    ].join("\n"),
  },
  {
    slot: "02_fast_memo_raised_pat_contrast",
    referenceImagePath:
      "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2_variants/02_fast_memo_raised_pat_01.jpg",
    prompt: [
      "Use the attached app icon as the reference and keep the exact same composition.",
      "Do not redesign the icon. Keep the same mint rounded-square background, the same memo card angle, the same three speed lines, and the same PAT lettering in the upper-left area.",
      "Create a slightly higher-contrast version.",
      "Make the PAT lettering more readable and more clearly embossed, with a bit more depth and separation from the paper.",
      "Also make the memo card edges, fold corner, and speed lines slightly clearer.",
      "Keep it elegant, soft, Apple-like, and premium. Do not make it harsh or over-processed.",
      "No new text, no purple, no extra elements.",
    ].join("\n"),
  },
];

async function generateVariant(apiKey, variant) {
  const parts = [{ text: variant.prompt }, await readInlineImage(variant.referenceImagePath)];
  const images = await generateByGemini({
    apiKey,
    model: DEFAULT_MODEL,
    parts,
    aspectRatio: "1:1",
    imageSize: "1K",
    count: 1,
  });

  const image = images[0];
  if (!image?.base64) {
    throw new Error(`No image returned for ${variant.slot}`);
  }

  const ext = extensionFromMime(image.mimeType);
  const outputPath = path.join(outputDir, `${variant.slot}_01.${ext}`);
  await writeBase64Image(outputPath, image.base64);

  const sidecarPath = sidecarPathFromImagePath(outputPath);
  await writeJson(sidecarPath, {
    slot: variant.slot,
    file: outputPath,
    model: DEFAULT_MODEL,
    referenceImagePath: variant.referenceImagePath,
    prompt: variant.prompt,
    source: "reference_edit_high_contrast",
  });

  return { slot: variant.slot, outputPath, sidecarPath };
}

async function main() {
  await fs.mkdir(outputDir, { recursive: true });
  const { apiKey } = await resolveApiKey("NANOBANANA_API_KEY");
  const results = [];
  for (const variant of variants) {
    results.push(await generateVariant(apiKey, variant));
  }
  console.log(JSON.stringify({ outputDir, results }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
