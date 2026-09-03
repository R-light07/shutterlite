import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
Deno.serve(async (req) => {
  try {
    const auth=req.headers.get("Authorization");
    if(!auth) return new Response("Unauthorized",{status:401});
    const client=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,
      {global:{headers:{Authorization:auth}}});
    const {data:{user}}=await client.auth.getUser();
    if(!user) return new Response("Unauthorized",{status:401});
    const {data:admin}=await client.from("mentoria_profiles").select("role,status").eq("id",user.id).maybeSingle();
    if(!admin || admin.role!=="admin" || admin.status!=="active") return new Response("Forbidden",{status:403});
    const {user_id}=await req.json();
    if(!user_id || user_id===user.id) return new Response("Invalid user_id",{status:400});
    const service=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const {error}=await service.auth.admin.deleteUser(user_id);
    if(error) throw error;
    return new Response(JSON.stringify({ok:true}),{headers:{"Content-Type":"application/json"}});
  } catch(e) { return new Response(String(e?.message||e),{status:500}); }
});
