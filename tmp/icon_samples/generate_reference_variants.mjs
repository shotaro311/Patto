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

const referenceImagePath =
  "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2/02_fast_memo_card_01.jpg";
const outputDir = "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2_variants";

const variants = [
  {
    slot: "02_fast_memo_centered_p",
    prompt: [
      "Use the attached app icon image as the reference and preserve the overall composition as much as possible.",
      "Keep the same pastel mint rounded-square background, the same flying memo card angle, the same soft shadow, and exactly three speed lines on the right side.",
      "Remove the small unclear text near the top-left of the memo.",
      'Instead, place one large elegant capital letter "P" in the center of the memo card.',
      "The P should be highly legible, premium, Apple-like, softly embossed or gently raised from the paper, refined and minimal.",
      "Do not add any other letters or words.",
      "Do not change the color family. No purple.",
      "Keep the icon cute, fast, polished, and suitable for the App Store.",
    ].join("\n"),
  },
  {
    slot: "02_fast_memo_raised_pat",
    prompt: [
      "Use the attached app icon image as the reference and preserve the overall composition as much as possible.",
      "Keep the same pastel mint rounded-square background, the same flying memo card angle, the same soft shadow, and exactly three speed lines on the right side.",
      'Keep a small title mark reading "PAT" in the same upper-left area of the memo card.',
      "Make the PAT lettering much clearer, more readable, and softly embossed so it stands out from the paper.",
      "Keep the lettering elegant, subtle, and premium rather than loud.",
      "Do not add any other text.",
      "Do not change the main layout or color family. No purple.",
      "Keep the icon Apple-like, fast, and clean.",
    ].join("\n"),
  },
];

async function generateVariant(apiKey, variant) {
  const parts = [{ text: variant.prompt }, await readInlineImage(referenceImagePath)];
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
    referenceImagePath,
    prompt: variant.prompt,
    source: "reference_edit",
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
  console.log(JSON.stringify({ referenceImagePath, outputDir, results }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
