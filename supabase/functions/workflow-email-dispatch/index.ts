import { createClient } from "npm:@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return response({ error: "Méthode non autorisée." }, 405);
  }

  const apiKey = Deno.env.get("BREVO_API_KEY");
  if (!apiKey) {
    return response({ error: "BREVO_API_KEY non configurée." }, 503);
  }

  const supabase = createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  await supabase
    .from("workflow_email_deliveries")
    .update({ status: "pending", claimed_at: null })
    .eq("status", "processing")
    .lt("claimed_at", new Date(Date.now() - 10 * 60_000).toISOString());
  const { data: deliveries, error } = await supabase
    .from("workflow_email_deliveries")
    .select(
      "id, user_id, concert_id, subject, body, attempts, notification_type, " +
        "concert_artist, concert_date, concert_time, venue_name, venue_address, " +
        "recipient_first_name, role_label",
    )
    .eq("status", "pending")
    .lte("next_attempt_at", new Date().toISOString())
    .order("created_at")
    .limit(25);
  if (error) return response({ error: error.message }, 500);

  let sent = 0;
  let failed = 0;
  for (const delivery of deliveries ?? []) {
    const claimedAt = new Date().toISOString();
    const { data: claimed } = await supabase
      .from("workflow_email_deliveries")
      .update({ status: "processing", claimed_at: claimedAt })
      .eq("id", delivery.id)
      .eq("status", "pending")
      .select("id")
      .maybeSingle();
    if (!claimed) continue;

    try {
      const { data: userResult, error: userError } = await supabase.auth.admin
        .getUserById(delivery.user_id);
      const email = userResult.user?.email;
      if (userError || !email) {
        throw userError ?? new Error("Adresse email introuvable.");
      }

      const messageId = await sendEmail(apiKey, {
        email,
        subject: buildSubject(delivery),
        body: delivery.body,
        concertId: delivery.concert_id,
        notificationType: delivery.notification_type,
        concertArtist: delivery.concert_artist,
        concertDate: delivery.concert_date,
        concertTime: delivery.concert_time,
        venueName: delivery.venue_name,
        venueAddress: delivery.venue_address,
        recipientFirstName: delivery.recipient_first_name,
        roleLabel: delivery.role_label,
      });
      await supabase.from("workflow_email_deliveries").update({
        status: "sent",
        sent_at: new Date().toISOString(),
        provider_message_id: messageId,
        last_error: null,
      }).eq("id", delivery.id);
      sent++;
    } catch (caught) {
      const attempts = Number(delivery.attempts) + 1;
      const terminal = attempts >= 5;
      const retryAt = new Date(
        Date.now() + Math.min(60, 2 ** attempts) * 60_000,
      ).toISOString();
      await supabase.from("workflow_email_deliveries").update({
        status: terminal ? "failed" : "pending",
        attempts,
        next_attempt_at: retryAt,
        last_error: errorMessage(caught).slice(0, 500),
      }).eq("id", delivery.id);
      failed++;
    }
  }

  return response({ processed: deliveries?.length ?? 0, sent, failed });
});

// "[Club Sandwich] — {date} — {lieu} — {titre}" for a concert-scoped
// delivery (French day + month name - Intl, not Postgres' locale-
// dependent to_char, which is why this is built here and not in SQL),
// "[Club Sandwich] — {titre}" otherwise (documents, conventions,
// invitations - nothing concert-scoped to anchor a date/lieu to).
function buildSubject(delivery: {
  subject: string;
  concert_date: string | null;
  venue_name: string | null;
}): string {
  if (delivery.concert_date && delivery.venue_name) {
    const formattedDate = new Intl.DateTimeFormat("fr-FR", {
      day: "numeric",
      month: "long",
    }).format(new Date(`${delivery.concert_date}T00:00:00`));
    return `[Club Sandwich] — ${formattedDate} — ${delivery.venue_name} — ${delivery.subject}`;
  }
  return `[Club Sandwich] — ${delivery.subject}`;
}

interface EmailMessage {
  email: string;
  subject: string;
  body: string;
  concertId: string | null;
  notificationType: string | null;
  concertArtist: string | null;
  concertDate: string | null;
  concertTime: string | null;
  venueName: string | null;
  venueAddress: string | null;
  recipientFirstName: string | null;
  roleLabel: string | null;
}

async function sendEmail(
  apiKey: string,
  message: EmailMessage,
): Promise<string | null> {
  const appUrl = Deno.env.get("APP_BASE_URL") ??
    "https://club-sandwich-preprod.netlify.app";
  const actionUrl = message.concertId
    ? `${appUrl}/#/maraudes/${message.concertId}`
    : `${appUrl}/#/dashboard`;
  const result = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      ...jsonHeaders,
      "accept": "application/json",
      "api-key": apiKey,
    },
    body: JSON.stringify({
      sender: {
        email: Deno.env.get("BREVO_SENDER_EMAIL") ??
          "maraudes@clubsandwich-records.com",
        name: "Club Sandwich",
      },
      to: [{ email: message.email }],
      subject: message.subject,
      textContent: `${message.body}\n\nOuvrir Club Sandwich : ${actionUrl}`,
      htmlContent: buildEmailHtml(message, actionUrl),
      tags: ["workflow"],
    }),
  });
  const payload = await result.json().catch(() => ({}));
  if (!result.ok) {
    throw new Error(payload.message ?? `Brevo HTTP ${result.status}`);
  }
  return payload.messageId ?? null;
}

const CARD_STYLE =
  "border:1px solid #e5e5ea;border-top:none;padding:24px 28px;" +
  "border-radius:0 0 12px 12px";

// Every email shares the same header/card/button shell. Mission-sheet
// emails (the 4 role emails, spec section 5) additionally get the fixed
// 9-block structure - salutation, role confirmation, a practical-info
// block, then the mission content, then a signature - built from the
// structured facts enqueue_workflow_email() now captures. Every other
// notification keeps the plain single-body rendering: that structure is
// scoped to the role emails specifically, not a general template change.
function buildEmailHtml(message: EmailMessage, actionUrl: string): string {
  const content = message.notificationType === "mission_sheet"
    ? buildMissionSheetContent(message)
    : renderBodyHtml(message.body);

  return `
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;
      margin:auto;color:#1a1a2e">
      <div style="background:#303b91;padding:20px 28px;border-radius:
        12px 12px 0 0">
        <h1 style="color:#fff;margin:0;font-size:18px">Club Sandwich</h1>
      </div>
      <div style="${CARD_STYLE}">
        ${content}
        <p style="margin:28px 0 0">
          <a href="${actionUrl}" style="background:#303b91;color:#fff;
            padding:12px 20px;border-radius:8px;text-decoration:none;
            display:inline-block;font-weight:bold">
            Ouvrir Club Sandwich
          </a>
        </p>
      </div>
    </div>
  `;
}

function buildMissionSheetContent(message: EmailMessage): string {
  const salutation = message.recipientFirstName
    ? `Bonjour ${escapeHtml(message.recipientFirstName)},`
    : "Bonjour,";

  const confirmation = message.concertArtist && message.roleLabel
    ? `Votre participation à la maraude ${
      escapeHtml(message.concertArtist)
    } est confirmée en tant que <strong>${
      escapeHtml(message.roleLabel)
    }</strong>.`
    : "Votre participation est confirmée.";

  return `
    <p style="margin:0 0 4px;line-height:1.5">${salutation}</p>
    <p style="margin:0 0 20px;line-height:1.5">${confirmation}</p>
    ${buildPracticalInfoBlock(message)}
    ${renderBodyHtml(message.body)}
    <p style="margin:24px 0 0;line-height:1.5">L’équipe Club Sandwich</p>
  `;
}

function buildPracticalInfoBlock(message: EmailMessage): string {
  const rows: Array<[string, string]> = [];
  if (message.concertDate) {
    const formatted = new Intl.DateTimeFormat("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
    }).format(new Date(`${message.concertDate}T00:00:00`));
    rows.push(["Date", formatted]);
  }
  if (message.concertTime) {
    rows.push(["Heure de rendez-vous", message.concertTime.slice(0, 5)]);
  }
  if (message.venueName) rows.push(["Lieu", message.venueName]);
  if (message.venueAddress) rows.push(["Adresse", message.venueAddress]);

  if (rows.length === 0) return "";

  const rowsHtml = rows.map(([label, value]) =>
    `<tr>
      <td style="padding:4px 12px 4px 0;color:#5a5a6e;white-space:nowrap;
        vertical-align:top">${escapeHtml(label)}</td>
      <td style="padding:4px 0;font-weight:600">${escapeHtml(value)}</td>
    </tr>`
  ).join("");

  return `
    <div style="background:#f4f4f8;border-radius:10px;padding:14px 18px;
      margin:0 0 20px">
      <p style="margin:0 0 8px;font-weight:700;color:#303b91;
        font-size:13px;text-transform:uppercase;letter-spacing:.03em">
        Informations pratiques
      </p>
      <table style="border-collapse:collapse;font-size:14px">
        ${rowsHtml}
      </table>
    </div>
  `;
}

// Notification bodies (private.maraude_role_mission_email_body and
// friends) are plain text: blank-line-separated sections, each optionally
// starting with a heading line followed by "- " bullet lines (mission
// sheets), or just plain sentences (simpler notifications). Dumping that
// straight into a single <p> collapsed every newline and bullet into one
// unreadable run-on paragraph - this rebuilds real headings/lists/
// paragraphs from the same plain-text convention instead.
function renderBodyHtml(body: string): string {
  const blocks = body
    .split(/\n\s*\n/)
    .map((block) => block.split("\n").filter((line) => line.trim().length > 0))
    .filter((lines) => lines.length > 0);

  return blocks.map((lines) => {
    const isBullet = (line: string) => line.trimStart().startsWith("- ");
    const bulletCount = lines.filter(isBullet).length;

    if (bulletCount === lines.length) {
      return renderList(lines);
    }
    if (lines.length > 1 && bulletCount === lines.length - 1 && !isBullet(lines[0])) {
      return renderHeading(lines[0]) + renderList(lines.slice(1));
    }
    return `<p style="margin:0 0 16px;line-height:1.5">${
      lines.map(escapeHtml).join("<br>")
    }</p>`;
  }).join("");
}

function renderHeading(text: string): string {
  return `<h3 style="margin:20px 0 8px;color:#303b91;font-size:15px">${
    escapeHtml(text)
  }</h3>`;
}

function renderList(lines: string[]): string {
  const items = lines.map((line) => line.trimStart().replace(/^- /, ""));
  return `<ul style="margin:0 0 16px;padding-left:20px;line-height:1.5">${
    items.map((item) => `<li style="margin-bottom:4px">${escapeHtml(item)}</li>`)
      .join("")
  }</ul>`;
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;",
  })[character] ?? character);
}

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
