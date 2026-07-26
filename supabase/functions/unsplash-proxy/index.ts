import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization token header." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const unsplashKey = Deno.env.get("UNSPLASH_ACCESS_KEY");
    if (!unsplashKey) {
      return new Response(
        JSON.stringify({ error: "Server configuration error: UNSPLASH_ACCESS_KEY secret is not set." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const topics = ["lifestyle", "workplace", "travel", "people", "city", "nature", "dining", "study"];
    const randomTopic = topics[Math.floor(Math.random() * topics.length)];
    const cacheBuster = Date.now();
    const unsplashResponse = await fetch(
      `https://api.unsplash.com/photos/random?query=${randomTopic}&orientation=landscape&cb=${cacheBuster}`,
      {
        method: "GET",
        headers: {
          "Authorization": `Client-ID ${unsplashKey}`,
        },
      }
    );

    const responseData = await unsplashResponse.json();

    return new Response(JSON.stringify(responseData), {
      status: unsplashResponse.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error in unsplash-proxy" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
