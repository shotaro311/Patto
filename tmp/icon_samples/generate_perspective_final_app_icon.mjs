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

const fullBleedReferencePath = "/Users/shotaro/code/shared/Patto/assets/icons/patto_app_icon_master.png";
const perspectiveReferencePath =
  "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2_variants_contrast/02_fast_memo_centered_p_contrast_01.jpg";
const outputDir = "/Users/shotaro/code/shared/Patto/assets/icons";
const slot = "patto_app_icon_master_perspective";
const prompt = [
  "You will receive two reference images.",
  "Use the first reference image for the full-bleed app icon composition, mint background treatment, centered P memo concept, and overall Apple-like premium softness.",
  "Use the second reference image only as the reference for the memo card's perspective tilt and depth feeling.",
  "Create one production-ready iOS/macOS app icon master.",
  "Keep the icon as a true full-bleed app icon with no inner rounded-square panel and no icon-inside-icon look.",
  "Keep the mint background, one memo card, centered P, folded corner, and exactly three speed lines on the right.",
  "Make the memo card larger, occupying about 72 to 76 percent of the canvas width while staying fully visible.",
  "Important: the memo card must have real perspective depth, not just a flat rotation. It should feel like the lower-left area is slightly closer to the viewer and the upper-right area is slightly farther away, with clear foreshortening and subtle thickness.",
  "The card should look like it is flying diagonally with depth, similar to the second reference image, not facing front.",
  "Keep it elegant, minimal, soft, and highly legible. No extra text, no purple, no extra symbols, no harsh contrast.",
].join("\n");

async function main() {
  await fs.mkdir(outputDir, { recursive: true });
  const { apiKey } = await resolveApiKey("NANOBANANA_API_KEY");
  const parts = [
    { text: prompt },
    await readInlineImage(fullBleedReferencePath),
    await readInlineImage(perspectiveReferencePath),
  ];
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
    throw new Error("No image returned for perspective final app icon.");
  }

  const ext = extensionFromMime(image.mimeType);
  const outputPath = path.join(outputDir, `${slot}.${ext}`);
  await writeBase64Image(outputPath, image.base64);

  const sidecarPath = sidecarPathFromImagePath(outputPath);
  await writeJson(sidecarPath, {
    slot,
    file: outputPath,
    model: DEFAULT_MODEL,
    fullBleedReferencePath,
    perspectiveReferencePath,
    prompt,
    source: "final_app_icon_perspective_edit",
  });

  console.log(
    JSON.stringify({ outputPath, sidecarPath, fullBleedReferencePath, perspectiveReferencePath }, null, 2),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
