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

const referenceImagePath = "/Users/shotaro/code/shared/Patto/assets/icons/patto_app_icon_master.png";
const outputDir = "/Users/shotaro/code/shared/Patto/assets/icons";
const slot = "patto_app_icon_master_large";
const prompt = [
  "Use the attached app icon as the reference and preserve the same design language.",
  "Keep the exact same full-bleed mint background, fast memo card concept, centered P, folded corner, three speed lines on the right, and Apple-like premium softness.",
  "Keep the icon as a true full-bleed app icon with no inner rounded-square panel and no icon-inside-icon look.",
  "Rotate the memo card back into a clear diagonal flying layout, similar to a memo slipping quickly across the screen. Do not make it face straight forward.",
  "Make the memo card and P much larger inside the icon, with the memo card occupying around 72 to 76 percent of the canvas width while staying fully visible.",
  "The memo card should feel clearly larger than the current app icon version, with tighter but still safe margins.",
  "The speed lines should scale with the card and remain visible on the right side.",
  "Do not redesign the icon. Do not add new elements. Do not add extra text.",
  "Keep the composition clean, strongly diagonal, and elegant for a real iOS/macOS app icon.",
  "No purple, no harsh contrast, no icon-inside-icon look.",
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
    throw new Error("No image returned for enlarged final app icon.");
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
    source: "final_app_icon_scale_up",
  });

  console.log(JSON.stringify({ outputPath, sidecarPath, referenceImagePath }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
