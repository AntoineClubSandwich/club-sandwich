import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) {
      return json({ error: "Authentification requise." }, 401);
    }

    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const anonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {
      data: { user: caller },
      error: callerError,
    } = await callerClient.auth.getUser();
    if (callerError || !caller) {
      return json({ error: "Session invalide." }, 401);
    }

    const { data: account, error: accountError } = await adminClient
      .from("user_accounts")
      .select("role, status")
      .eq("profile_id", caller.id)
      .maybeSingle();

    if (account?.role !== "admin" || account?.status !== "active") {
      return json({ error: "Accès administrateur requis." }, 403);
    }

    const body = await request.json();
    switch (body.action) {
      case "invite":
        return await inviteUser(adminClient, body);
      case "resend":
        return await resendInvitation(adminClient, body);
      case "update":
        return await updateUser(adminClient, body);
      case "disable":
        return await setDisabled(adminClient, body.profileId, true);
      case "reactivate":
        return await setDisabled(adminClient, body.profileId, false);
      default:
        return json({ error: "Action inconnue." }, 400);
    }
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Une erreur inattendue est survenue.";
    return json({ error: message }, 400);
  }
});

async function inviteUser(client: ReturnType<typeof createClient>, body: any) {
  validateIdentity(body);
  const redirectTo = requiredString(body.redirectTo, "URL d’activation");
  const email = body.email.trim().toLowerCase();
  const metadata = {
    first_name: body.firstName.trim(),
    last_name: body.lastName.trim(),
  };
  const { data, error } = await client.auth.admin.inviteUserByEmail(
    email,
    {
      redirectTo,
      data: metadata,
    },
  );
  let user = data.user;
  let activationUrl: string | null = null;
  let emailSent = true;

  if (error) {
    if (!isEmailRateLimit(error.message)) throw error;
    const { data: generated, error: generationError } = await client.auth.admin
      .generateLink({
        type: "invite",
        email,
        options: { redirectTo, data: metadata },
      });
    if (generationError || !generated.user) {
      throw generationError ?? new Error("Invitation impossible.");
    }
    user = generated.user;
    activationUrl = generated.properties.action_link;
    emailSent = false;
  }
  if (!user) throw new Error("Invitation impossible.");

  const { error: accountError } = await client.from("user_accounts").upsert({
    profile_id: user.id,
    role: body.role,
    organization_id: body.role === "promoter" ? body.organizationId : null,
    status: "invited",
    invited_at: new Date().toISOString(),
    activated_at: null,
    disabled_at: null,
  });
  if (accountError) {
    await client.auth.admin.deleteUser(user.id);
    throw accountError;
  }
  return json({
    profileId: user.id,
    emailSent,
    activationUrl,
  }, 201);
}

function isEmailRateLimit(message: string): boolean {
  return /rate.?limit|over_email_send_rate_limit/i.test(message);
}

async function resendInvitation(
  client: ReturnType<typeof createClient>,
  body: any,
) {
  const profileId = requiredString(body.profileId, "Utilisateur");
  const redirectTo = requiredString(body.redirectTo, "URL d’activation");
  const { data: userResult, error: userError } = await client.auth.admin
    .getUserById(profileId);
  if (userError || !userResult.user?.email) {
    throw userError ?? new Error("Utilisateur introuvable.");
  }

  // Un compte qui a déjà cliqué son lien une première fois (email confirmé,
  // même si l'activation applicative n'a pas abouti) ne peut plus recevoir
  // d'invitation : GoTrue la refuse pour un e-mail déjà confirmé. On bascule
  // alors sur un e-mail de réinitialisation, qui redonne un lien valide pour
  // définir un mot de passe et terminer l'activation.
  if (userResult.user.email_confirmed_at) {
    const { error: recoveryError } = await client.auth.resetPasswordForEmail(
      userResult.user.email,
      { redirectTo },
    );
    if (recoveryError) throw recoveryError;
  } else {
    const { error } = await client.auth.admin.inviteUserByEmail(
      userResult.user.email,
      {
        redirectTo,
        data: userResult.user.user_metadata,
      },
    );
    if (error) throw error;
  }
  await client.from("user_accounts").update({
    status: "invited",
    invited_at: new Date().toISOString(),
    activated_at: null,
    disabled_at: null,
  }).eq("profile_id", profileId);
  return json({ ok: true });
}

async function updateUser(client: ReturnType<typeof createClient>, body: any) {
  const profileId = requiredString(body.profileId, "Utilisateur");
  validateRole(body.role, body.organizationId);
  const { error } = await client.from("user_accounts").update({
    role: body.role,
    organization_id: body.role === "promoter" ? body.organizationId : null,
    updated_at: new Date().toISOString(),
  }).eq("profile_id", profileId);
  if (error) throw error;
  return json({ ok: true });
}

async function setDisabled(
  client: ReturnType<typeof createClient>,
  profileIdValue: unknown,
  disabled: boolean,
) {
  const profileId = requiredString(profileIdValue, "Utilisateur");
  const { error: authError } = await client.auth.admin.updateUserById(
    profileId,
    { ban_duration: disabled ? "876000h" : "none" },
  );
  if (authError) throw authError;

  const { error } = await client.from("user_accounts").update({
    status: disabled ? "disabled" : "active",
    disabled_at: disabled ? new Date().toISOString() : null,
    activated_at: disabled ? undefined : new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }).eq("profile_id", profileId);
  if (error) throw error;
  return json({ ok: true });
}

function validateIdentity(body: any) {
  requiredString(body.firstName, "Prénom");
  requiredString(body.lastName, "Nom");
  const email = requiredString(body.email, "Adresse e-mail");
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new Error("L’adresse e-mail est invalide.");
  }
  validateRole(body.role, body.organizationId);
}

function validateRole(role: unknown, organizationId: unknown) {
  if (role !== "admin" && role !== "promoter" && role !== "volunteer") {
    throw new Error("Le rôle est invalide.");
  }
  if (role === "promoter") {
    requiredString(organizationId, "Organisation");
  }
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${field} est obligatoire.`);
  }
  return value.trim();
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Configuration serveur manquante : ${name}`);
  return value;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
