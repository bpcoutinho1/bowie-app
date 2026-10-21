# Ligar e desligar o Premium (testes)

Enquanto a assinatura não está no app, o plano de cada conta é mudado à mão no Supabase. Como funciona: [planos](../funcionamento/planos.md). As regras: [planos e preço](../produto/planos.md).

## 1. Banco (uma vez)

No SQL Editor do Supabase, rode `supabase/migrations/20261019120000_account_plans.sql` (Copy raw file no GitHub, colar, Run). Ela cria a tabela `account_plans`, dá a cada conta nova 30 dias de Premium e coloca as contas que já existem no plano grátis (o teste delas conta a partir de quando foram criadas).

## 2. Mudar o plano

No SQL Editor, troque `seu@email.com` pelo email da conta e rode o comando do que quiser testar. O app lê o plano de novo a cada verificação: não precisa reinstalar. Em "Minha conta", saia e entre de novo na tela para ver o plano atualizado.

**Ver o plano da conta**

A coluna `plan` diz `free` também durante o teste de 30 dias: toda conta nova nasce assim. A última coluna desta consulta mostra o plano que o app usa de fato.

```sql
select email, plan, premium_until, trial_ends_at, ai_photos_used, diary_files_used,
  case
    when plan = 'premium' and (premium_until is null or premium_until > now()) then 'Premium'
    when trial_ends_at > now() then 'Teste do Premium (até ' || to_char(trial_ends_at, 'DD/MM') || ')'
    else 'Grátis'
  end as plano_no_app
from account_plans where email = 'seu@email.com';
```

**Ligar o Premium (sem data para acabar)**

```sql
update account_plans set plan = 'premium', premium_until = null, updated_at = now()
where email = 'seu@email.com';
```

**Premium até uma data**

```sql
update account_plans set plan = 'premium', premium_until = '2026-12-31', updated_at = now()
where email = 'seu@email.com';
```

**Voltar para o grátis (e encerrar o teste de 30 dias)**

```sql
update account_plans set plan = 'free', premium_until = null, trial_ends_at = now(), updated_at = now()
where email = 'seu@email.com';
```

**Dar 30 dias de teste de novo**

```sql
update account_plans set trial_ends_at = now() + interval '30 days', updated_at = now()
where email = 'seu@email.com';
```

**Zerar o que o plano grátis já contou**

```sql
update account_plans set ai_photos_used = 0, diary_files_used = 0, updated_at = now()
where email = 'seu@email.com';
```

Para testar o grátis numa conta nova, rode "Voltar para o grátis": sem isso, ela está no teste e pode cadastrar até 10 pets.

Também dá para editar pelo **Table Editor → account_plans**: clique duas vezes na célula (`plan`, `trial_ends_at`, os contadores), mude e salve.

## 3. O que testar

| Plano | O que acontece |
| --- | --- |
| Grátis, com 1 pet | "Adicionar pet" abre "Bowie Premium": "No plano grátis, a conta tem 1 pet." |
| Grátis, 3 fotos já lidas | A leitura da carteirinha abre "Bowie Premium" antes de enviar as fotos |
| Grátis, 5 envios no diário | Salvar um registro com foto ou PDF novo abre "Bowie Premium" |
| Premium ou teste | Até 10 pets, leitura e diário sem limite |
| Premium com 10 pets | "Limite do plano: o Premium tem até 10 pets por conta." |

Os pets que a conta já tem continuam todos lá: o limite só impede de cadastrar mais.

No topo de "Minha conta", o cartão do plano mostra o que o app leu ("Conta: Teste grátis do Premium", "Acaba em: 18/11/2026"). Se aparecer "Não foi possível ver o plano" com internet, a migração não foi rodada ou o app é de antes dela (refaça o build depois do `git pull`).

## 4. Assinatura pelas lojas

Quem assina pelo app tem o Premium ligado sozinho, nas colunas `store_premium_until` e `store_product`, sem mexer no `plan`. Os comandos acima continuam valendo para testes e cortesias: o Premium dado à mão e o comprado na loja não se apagam. Para ligar a cobrança: [assinaturas](assinaturas.md).
