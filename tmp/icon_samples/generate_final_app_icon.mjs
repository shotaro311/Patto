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
  "/Users/shotaro/code/shared/Patto/tmp/icon_samples/generated_v2_variants_contrast/02_fast_memo_centered_p_contrast_01.jpg";
const outputDir = "/Users/shotaro/code/shared/Patto/assets/icons";
const slot = "patto_app_icon_master";
const prompt = [
  "Use the attached icon as the reference and keep the same core design language.",
  "Create a production-ready Apple-style app icon master for Patto.",
  "Keep the fast flying memo card, the large centered P, the folded corner, and exactly three speed lines on the right.",
  "Important: remove the inner rounded-square panel and redesign this as one proper full-bleed app icon composition.",
  "The entire square canvas should be the icon background, edge to edge, with no outer white corners and no icon-inside-icon look.",
  "Use a soft mint full background with very subtle shading only, not an obvious gradient.",
  "Keep the memo card premium, softly embossed, and clearly readable. Make the centered P elegant, legible, and slightly raised.",
  "Center the composition with safe margins suitable for iOS and macOS app icons, knowing the OS will round the corners.",
  "Keep it minimal, polished, cute, and Apple-like.",
  "No extra text, no extra symbols, no purple, no transparency, no photo realism.",
].join("\n");

async function main() {
  await fs.mkdir(outputDir, { recursive: true });
  const { apiKey } = await resolveApiKey("NANOBANANA_API_KEY");
  const parts = [{ text: prompt }, await readInlineImage(referenceImagePath)];
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
    throw new Error("No image returned for final app icon.");
  }

  const ext = extensionFromMime(image.mimeType);
  const outputPath = path.join(outputDir, `${slot}.${ext}`);
  await writeBase64Image(outputPath, image.base64);

  const sidecarPath = sidecarPathFromImagePath(outputPath);
  await writeJson(sidecarPath, {
    slot,
    file: outputPath,
    model: DEFAULT_MODEL,
    referenceImagePath,
    prompt,
    source: "final_app_icon_reference_edit",
  });

  console.log(JSON.stringify({ outputPath, sidecarPath, referenceImagePath }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
