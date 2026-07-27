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

    const { data: account } = await adminClient
      .from("user_accounts")
      .select("role, status")
      .eq("profile_id", caller.id)
      .maybeSingle();
    if (account?.role !== "admin" || account.status !== "active") {
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
  const { data, error } = await client.auth.admin.inviteUserByEmail(
    body.email.trim().toLowerCase(),
    {
      redirectTo,
      data: {
        first_name: body.firstName.trim(),
        last_name: body.lastName.trim(),
      },
    },
  );
  if (error || !data.user) throw error ?? new Error("Invitation impossible.");

  const { error: accountError } = await client.from("user_accounts").upsert({
    profile_id: data.user.id,
    role: body.role,
    organization_id: body.role === "promoter" ? body.organizationId : null,
    status: "invited",
    invited_at: new Date().toISOString(),
    activated_at: null,
    disabled_at: null,
  });
  if (accountError) {
    await client.auth.admin.deleteUser(data.user.id);
    throw accountError;
  }
  return json({ profileId: data.user.id }, 201);
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
  const { error } = await client.auth.admin.inviteUserByEmail(
    userResult.user.email,
    {
      redirectTo,
      data: userResult.user.user_metadata,
    },
  );
  if (error) throw error;
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
