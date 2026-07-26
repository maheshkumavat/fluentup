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

    const githubPat = Deno.env.get("GITHUB_PAT");
    const headers: Record<string, string> = {
      "Accept": "application/vnd.github.v3+json",
      "User-Agent": "FluentUp-App",
    };

    if (githubPat && githubPat.trim().length > 0) {
      headers["Authorization"] = `Bearer ${githubPat.trim()}`;
    }

    const githubResponse = await fetch(
      "https://api.github.com/repos/maheshkumavat/fluentup/releases/latest",
      {
        method: "GET",
        headers: headers,
      }
    );

    const responseData = await githubResponse.json();

    return new Response(JSON.stringify(responseData), {
      status: githubResponse.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error in version-proxy" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
