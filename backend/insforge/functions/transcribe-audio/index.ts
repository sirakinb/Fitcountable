type TranscribeAudioRequest = {
  audioBase64?: string;
  audio_base64?: string;
  mimeType?: string;
  mime_type?: string;
};

export default async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  const apiKey = Deno.env.get("DEEPGRAM_API_KEY");
  if (!apiKey) {
    return Response.json({ error: "DEEPGRAM_API_KEY is not configured" }, { status: 500 });
  }

  let body: TranscribeAudioRequest;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const audioBase64 = (body.audioBase64 ?? body.audio_base64)?.trim();
  const mimeType = (body.mimeType ?? body.mime_type)?.trim() || "audio/wav";
  if (!audioBase64) {
    return Response.json({ error: "audioBase64 is required" }, { status: 400 });
  }
  if (audioBase64.length > 20_000_000) {
    return Response.json({ error: "Audio clip is too large" }, { status: 413 });
  }

  const audio = Uint8Array.from(atob(audioBase64), (character) => character.charCodeAt(0));
  const deepgramResponse = await fetch("https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&punctuate=true", {
    method: "POST",
    headers: {
      Authorization: `Token ${apiKey}`,
      "Content-Type": mimeType
    },
    body: audio
  });

  if (!deepgramResponse.ok) {
    const detail = await deepgramResponse.text();
    return Response.json(
      {
        error: `Deepgram transcription failed with status ${deepgramResponse.status}`,
        detail: detail.slice(0, 500)
      },
      { status: 502 }
    );
  }

  const payload = await deepgramResponse.json();
  const transcript = payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript;
  if (typeof transcript !== "string") {
    return Response.json({ error: "Deepgram returned an invalid transcription response" }, { status: 502 });
  }

  return Response.json({ transcript });
}
