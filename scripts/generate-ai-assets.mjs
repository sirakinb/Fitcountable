#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { generateText } from "../backend/node_modules/ai/dist/index.mjs";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const secretsPath = "/Users/sirakinb/Documents/Projects/ios-release-pipeline/secrets.local.json";
const model = "google/gemini-3.1-flash-image-preview";

const outputs = [
  {
    name: "fitcountable-app-icon",
    output: "ios/Fitcountable/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    prompt: "Create a world-class square iOS app icon for Fitcountable, an AI-native workout and nutrition accountability app. Make it a distinctive Duolingo-like mascot/avatar character, but original: a friendly energetic fitness accountability companion with a rounded face, expressive eyes, subtle progress-ring halo, and a small checkmark/count motif worked into the character. Premium Gen Z fitness tech aesthetic, blue/green/black palette, high contrast, centered character, no text, no letters, no medical symbols, no tiny detail, legible at 60px, polished App Store icon.",
  },
  {
    name: "OnboardingHero",
    output: "ios/Fitcountable/Assets.xcassets/OnboardingHero.imageset/onboarding-hero.png",
    prompt: "Create a world-class portrait abstract brand visual for Fitcountable, a premium AI fitness app. Use only luminous progress rings, voice waveform energy, clean geometric macro bars, checkmark motifs, and subtle social connection nodes. Do not include any UI cards, labels, typography, letters, words, numbers, icons containing text, humans, food photos, or readable marks. It should look like premium Apple-quality app artwork, blue/green/black palette, high detail, polished, App Store-safe.",
  },
  {
    name: "AccountabilityHero",
    output: "ios/Fitcountable/Assets.xcassets/AccountabilityHero.imageset/accountability-hero.png",
    prompt: "Create a world-class photorealistic warm onboarding image for Fitcountable, an accountability-focused fitness app. Show two brown-skinned young adult friends in modern gym or outdoor fitness attire sharing a genuine supportive handshake/fist-clasp after a workout, friendly and aspirational, no exaggerated muscles, no body-shaming, no medical context. Bright premium mobile-app composition, natural light, shallow depth of field, polished Apple App Store quality, room for cropping in a rounded rectangle, no text, no logos, no words, no watermarks.",
  },
  {
    name: "WeeklyTargetHero",
    output: "ios/Fitcountable/Assets.xcassets/WeeklyTargetHero.imageset/weekly-target-hero.png",
    prompt: "Create a world-class hyperrealistic onboarding image for Fitcountable about setting a weekly fitness target. Show a brown-skinned young adult athlete in a premium modern gym or outdoor training space using a phone or smartwatch to set weekly workout goals, with subtle visual cues of a target, calendar, or progress rings in the environment but absolutely no readable text, numbers, logos, UI words, or watermarks. Warm aspirational natural light, polished Apple App Store quality, fitness goal-setting mood, no body-shaming, no medical claims, crop-safe rounded rectangle composition.",
  },
  {
    name: "PaywallHero",
    output: "ios/Fitcountable/Assets.xcassets/PaywallHero.imageset/paywall-hero.png",
    prompt: "Create a world-class portrait premium subscription visual for Fitcountable. Use abstract luminous stacked glass panels, progress rings, checkmark streak path, shield-like premium motif, and friend accountability nodes. Do not include any typography, words, letters, numbers, plan names, buttons, UI labels, humans, or readable marks. Premium Apple-quality fintech/fitness aesthetic, blue/green/black palette, high contrast, polished, App Store-safe.",
  },
  {
    name: "landing-hero",
    output: "web/public/fitcountable-hero.png",
    prompt: "Create a wide web landing page hero image for Fitcountable. Abstract product scene only: voice waveform and command glow transform into structured workout, meal, macro, and accountability cards. No humans, no letters, no words, no numbers, no readable text anywhere. Premium fitness technology, clean bright composition, blue/green/black accents, leave space on the left for overlaid headline, no medical claims.",
  },
  {
    name: "app-store-background",
    output: "assets/generated/app-store-background.png",
    prompt: "Create a vertical App Store screenshot background for Fitcountable, a premium AI fitness tracker. Include abstract calorie dashboard rings, workout set rows, voice command waveforms, and friend accountability proof elements around the edges, with a clean safe central area for iPhone screenshots and headline text. No readable text.",
  },
];

async function main() {
  const secretPayload = JSON.parse(await fs.readFile(secretsPath, "utf8"));
  const gateway = secretPayload.vercelAiGateway;
  if (!gateway?.apiKey || !gateway?.envKey) {
    throw new Error("Missing Vercel AI Gateway credentials in secrets.local.json");
  }
  process.env[gateway.envKey] = gateway.apiKey;
  process.env.AI_GATEWAY_API_KEY ||= gateway.apiKey;

  const requestedNames = new Set(process.argv.slice(2));
  const selectedOutputs = requestedNames.size
    ? outputs.filter((asset) => requestedNames.has(asset.name))
    : outputs;

  for (const asset of selectedOutputs) {
    const result = await generateText({
      model,
      prompt: asset.prompt,
    });
    const image = result.files?.find((file) => file.mediaType?.startsWith("image/"));
    if (!image?.uint8Array) {
      throw new Error(`No image returned for ${asset.name}`);
    }

    const outputPath = path.join(rootDir, asset.output);
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, image.uint8Array);
    await writeImageSetContents(asset.output);
    console.log(`Generated ${asset.name}: ${asset.output}`);
  }
}

async function writeImageSetContents(output) {
  if (!output.includes(".imageset/")) return;
  const imageSetDir = path.dirname(path.join(rootDir, output));
  const filename = path.basename(output);
  const contents = {
    images: [
      { filename, idiom: "universal", scale: "1x" },
      { idiom: "universal", scale: "2x" },
      { idiom: "universal", scale: "3x" },
    ],
    info: { author: "xcode", version: 1 },
  };
  await fs.writeFile(path.join(imageSetDir, "Contents.json"), `${JSON.stringify(contents, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
