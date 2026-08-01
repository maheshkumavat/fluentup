import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { MsEdgeTTS, OUTPUT_FORMAT } from "npm:msedge-tts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const reqBody = await req.json();
    const text = (reqBody && reqBody.text) ? String(reqBody.text) : "";
    const voice = (reqBody && reqBody.voice) ? String(reqBody.voice) : "en-US-AriaNeural";
    const rate = (reqBody && reqBody.rate) ? String(reqBody.rate) : "+0%";

    if (!text || text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Text parameter is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tts = new MsEdgeTTS();
    await tts.setMetadata(voice, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
    const { audioStream } = await tts.toStream(text.trim(), { rate });

    const chunks: Uint8Array[] = [];

    await new Promise<void>((resolve, reject) => {
      audioStream.on("data", (chunk: any) => {
        chunks.push(new Uint8Array(chunk));
      });
      audioStream.on("end", () => resolve());
      audioStream.on("error", (err: any) => reject(err));
    });

    const totalLen = chunks.reduce((acc, c) => acc + c.byteLength, 0);
    const combined = new Uint8Array(totalLen);
    let offset = 0;
    for (const chunk of chunks) {
      combined.set(chunk, offset);
      offset += chunk.byteLength;
    }

    let binary = "";
    const len = combined.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(combined[i]);
    }
    const base64Audio = btoa(binary);

    return new Response(
      JSON.stringify({
        success: true,
        voice: voice,
        audio_base64: base64Audio,
        byte_length: combined.byteLength
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Error synthesizing audio in tts-proxy" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
