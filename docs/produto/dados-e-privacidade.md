# Dados, sincronização e privacidade

## Funciona sem internet

Tudo funciona no aparelho primeiro: cadastrar, editar, marcar compras e registrar incidentes. Quando há internet, as alterações sobem para o servidor. O código atual já segue esse modelo para pets e tutores (veja [sincronização](../funcionamento/sincronizacao.md)).

Fotos (do pet, da carteirinha e dos incidentes) também precisam ser salvas no aparelho primeiro e enviadas depois.

## Sincronização entre tutores

Uma alteração feita por qualquer tutor deve aparecer para os outros **logo depois de feita**, sem precisar abrir e fechar o app ou tocar em "sincronizar".

O código atual só sincroniza em momentos específicos (login, alteração local, mudança de conexão, botão). Para cumprir esta regra, o app vai precisar ouvir mudanças do servidor em tempo real (por exemplo, com o Supabase Realtime) e sincronizar também ao voltar do segundo plano.

## LGPD desde o início

O app guarda dados pessoais dos tutores (nome, email, celular) e dados de saúde dos pets, com fotos. Regras:

- **Consentimento claro** no cadastro, com links para os termos de uso e a política de privacidade.
- **Dados mínimos:** só pedir o que o app usa. O celular serve para recuperar a senha por WhatsApp e, com consentimento à parte, para SMS comerciais (veja [contas e tutores](contas-e-tutores.md#para-que-serve-o-celular)).
- **Marketing só com opt-in:** SMS e outras mensagens comerciais exigem um consentimento próprio, separado dos termos de uso, desmarcado por padrão e revogável no app. O app guarda quando e como a pessoa aceitou.
- **Exportação:** a pessoa pode baixar os próprios dados e os dos pets dela.
- **Exclusão de conta:** a pessoa pode apagar a conta pelo próprio app. A App Store e o Google Play também exigem isso. Se ela for tutora principal de algum pet, o app pede para transferir ou excluir o pet antes.
- **Acesso restrito:** só os tutores de um pet veem os dados e as fotos dele. Arquivos ficam em armazenamento privado, não em links públicos.
- **Nada sensível em logs:** sem email, celular, nomes ou conteúdo de saúde em logs e relatórios de erro.
- **Sair da conta limpa o aparelho:** os dados locais de uma conta não podem ficar disponíveis para a próxima pessoa que entrar no mesmo aparelho. O código atual ainda não faz isso.
- **Controlador dos dados:** no início, o Bruno como pessoa física. Quando houver CNPJ, os termos e a política precisam ser atualizados.
