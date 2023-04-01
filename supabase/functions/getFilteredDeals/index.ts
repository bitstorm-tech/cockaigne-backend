// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import { Client } from "postgres";
import { serve } from "server";

const dbUrl = Deno.env.get("SUPABASE_DB_URL");
console.log("URL:", dbUrl);
const client = new Client(dbUrl);
console.log("Outside of serve");

serve(async (req) => {
  console.log("Inside of serve");

  try {
    console.log("Create connection");
    await client.connect();
    console.log("Connection created");
    const accounts = await client.queryArray`SELECT * FROM accounts`;
    console.log("Accounts:", accounts);
    return new Response("Läuft!");
  } catch (error) {
    console.log("Error: ", error);
    return new Response(`Error: ${error}`, { status: 500 });
  } finally {
    client?.end();
  }
});

// To invoke:
// curl -i --location --request POST 'http://localhost:54321/functions/v1/getFilteredDeals' \
//   --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
//   --header 'Content-Type: application/json' \
//   --data '{"name":"Functions"}'end()
