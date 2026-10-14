SHUTTERLITE — MENTORIAS ONLINE
================================

Ficheiros:
- mentorias.sql             -> tabelas, RPCs e RLS
- mentorias.html            -> página pública + candidatura
- mentorias-login.html      -> login do aluno
- mentorias-area.html       -> área privada
- INTEGRACAO.txt            -> alterações necessárias no website/admin

IMPORTANTE
1. Execute mentorias.sql no Supabase SQL Editor.
2. O projeto atual usa a chave anon no frontend. Ela é apropriada para frontend quando RLS está corretamente configurado.
3. A área privada usa Supabase Auth.
4. O administrador da mentoria deve ser uma conta do Supabase Auth com um registo em mentoria_profiles role=admin/status=active.
5. Não coloque Service Role Key em HTML/JavaScript.
6. O envio de candidatura só pode criar status pending através da RPC.
7. Aprovação/rejeição só ocorre pela RPC e exige perfil admin.
