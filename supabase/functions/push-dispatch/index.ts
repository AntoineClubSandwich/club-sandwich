import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return response({ error: "Méthode non autorisée." }, 405);
  }

  const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  const vapidSubject = Deno.env.get("VAPID_SUBJECT");
  if (!vapidPublicKey || !vapidPrivateKey || !vapidSubject) {
    return response({ error: "Clés VAPID non configurées." }, 503);
  }
  webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const supabase = createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  await supabase
    .from("workflow_push_deliveries")
    .update({ status: "pending", claimed_at: null })
    .eq("status", "processing")
    .lt("claimed_at", new Date(Date.now() - 10 * 60_000).toISOString());

  const { data: deliveries, error } = await supabase
    .from("workflow_push_deliveries")
    .select("id, user_id, concert_id, title, body, attempts")
    .eq("status", "pending")
    .lte("next_attempt_at", new Date().toISOString())
    .order("created_at")
    .limit(25);
  if (error) return response({ error: error.message }, 500);

  let sent = 0;
  let skipped = 0;
  let failed = 0;
  for (const delivery of deliveries ?? []) {
    const claimedAt = new Date().toISOString();
    const { data: claimed } = await supabase
      .from("workflow_push_deliveries")
      .update({ status: "processing", claimed_at: claimedAt })
      .eq("id", delivery.id)
      .eq("status", "pending")
      .select("id")
      .maybeSingle();
    if (!claimed) continue;

    try {
      const { data: subscriptions, error: subscriptionsError } =
        await supabase
          .from("push_subscriptions")
          .select("id, endpoint, p256dh, auth_key")
          .eq("user_id", delivery.user_id);
      if (subscriptionsError) throw subscriptionsError;

      if (!subscriptions || subscriptions.length === 0) {
        await supabase.from("workflow_push_deliveries").update({
          status: "skipped",
          sent_at: new Date().toISOString(),
          last_error: null,
        }).eq("id", delivery.id);
        skipped++;
        continue;
      }

      const payload = JSON.stringify({
        title: delivery.title,
        body: delivery.body,
        concertId: delivery.concert_id,
      });

      let successCount = 0;
      let lastError: unknown = null;
      for (const subscription of subscriptions) {
        try {
          await webpush.sendNotification(
            {
              endpoint: subscription.endpoint,
              keys: {
                p256dh: subscription.p256dh,
                auth: subscription.auth_key,
              },
            },
            payload,
          );
          successCount++;
          await supabase.from("push_subscriptions").update({
            last_used_at: new Date().toISOString(),
          }).eq("id", subscription.id);
        } catch (caught) {
          const statusCode = (caught as { statusCode?: number })?.statusCode;
          if (statusCode === 404 || statusCode === 410) {
            await supabase.from("push_subscriptions").delete().eq(
              "id",
              subscription.id,
            );
            continue;
          }
          lastError = caught;
        }
      }

      if (successCount > 0) {
        await supabase.from("workflow_push_deliveries").update({
          status: "sent",
          sent_at: new Date().toISOString(),
          last_error: null,
        }).eq("id", delivery.id);
        sent++;
      } else if (lastError === null) {
        await supabase.from("workflow_push_deliveries").update({
          status: "skipped",
          sent_at: new Date().toISOString(),
          last_error: "Abonnements expirés, aucun appareil actif.",
        }).eq("id", delivery.id);
        skipped++;
      } else {
        throw lastError;
      }
    } catch (caught) {
      const attempts = Number(delivery.attempts) + 1;
      const terminal = attempts >= 5;
      const retryAt = new Date(
        Date.now() + Math.min(60, 2 ** attempts) * 60_000,
      ).toISOString();
      await supabase.from("workflow_push_deliveries").update({
        status: terminal ? "failed" : "pending",
        attempts,
        next_attempt_at: retryAt,
        last_error: errorMessage(caught).slice(0, 500),
      }).eq("id", delivery.id);
      failed++;
    }
  }

  return response({ processed: deliveries?.length ?? 0, sent, skipped, failed });
});

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} non configurée.`);
  return value;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Erreur inconnue.";
}

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}
