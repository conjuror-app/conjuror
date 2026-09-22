#!/usr/bin/env node

/** Generate the checked-in emoji catalog from Unicode's emoji-test data. */

import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { deflateRawSync } from "node:zlib";

const version = "latest";
const url = `https://unicode.org/Public/emoji/${version}/emoji-test.txt`;
const annotationURLs = [
  "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/en/annotations.json",
  "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-derived-full/annotationsDerived/en/annotations.json",
];
const output = "Conjuror/Resources/EmojiCatalog.data";

const [response, ...annotationResponses] = await Promise.all(
  [url, ...annotationURLs].map(async (sourceURL) => {
    const sourceResponse = await fetch(sourceURL);

    if (!sourceResponse.ok) {
      throw new Error(
        `Could not download ${sourceURL}: ${sourceResponse.status} ${sourceResponse.statusText}`,
      );
    }

    return sourceResponse;
  }),
);

const annotations = new Map();

for (const annotationResponse of annotationResponses) {
  const data = await annotationResponse.json();
  const entries = data.annotations?.annotations ?? data.annotationsDerived?.annotations;

  for (const [emoji, annotation] of Object.entries(entries)) {
    const existing = annotations.get(emoji) ?? [];
    annotations.set(emoji, [...new Set([...existing, ...(annotation.default ?? [])])]);
  }
}

const entries = [];
let category = "";

for (const line of (await response.text()).split("\n")) {
  if (line.startsWith("# group: ")) {
    category = line.slice("# group: ".length).trim();
    continue;
  }

  const match = line.match(
    /^([0-9A-F ]+)\s*; fully-qualified\s*#\s*\S+\s+E[0-9.]+\s+(.+)$/,
  );
  if (!match) continue;

  const value = match[1]
    .trim()
    .split(/\s+/)
    .map((codePoint) => String.fromCodePoint(Number.parseInt(codePoint, 16)))
    .join("");

  entries.push({
    value,
    name: match[2].trim(),
    category,
    keywords: annotations.get(value) ?? [],
  });
}

const catalog = entries
  .map(
    ({ value, name, category, keywords }) =>
      `${value}|${name}|${category}|${keywords.join(",")}`,
  )
  .join("\n");

await mkdir(dirname(output), { recursive: true });
await writeFile(output, deflateRawSync(catalog, { level: 9 }));
console.log(`Generated ${entries.length} compressed emoji in ${output}`);
