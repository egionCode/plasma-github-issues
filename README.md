# GitHub Issues para KDE Plasma 6

Widget (plasmoid) que lista as issues abertas dos seus repositórios do GitHub,
agrupadas por repo, direto no desktop ou no painel do Plasma.

## Recursos

- Filtros: todas, atribuídas a mim, criadas por mim, mencionadas, nos meus repos
- Busca local por título, repo, label, autor ou número (vários termos = todos precisam casar)
- Repos ordenados pela atividade mais recente; cabeçalho recolhível com contagem e issues recuadas sob ele
- Modo "lista única" (sem agrupar): ordena tudo por atividade e mostra o repo em cada linha. Alterna pelo botão na barra do widget ou em Configurar
- Destaque de issues novas ou atualizadas desde a última vez que você viu
- Notificação quando chega issue nova entre duas atualizações
- Clique abre no navegador; clique direito: abrir, copiar link, marcar como vista
- Ícone no painel com contador (cor de destaque quando há novas)
- Labels com a cor do GitHub e contraste automático do texto

## Requisitos

- KDE Plasma 6
- [GitHub CLI](https://cli.github.com) (`gh`) autenticado: `gh auth login`

O token é lido em tempo de execução com `gh auth token` (ou da variável `GH_TOKEN`,
que tem prioridade). Ele não é gravado em disco nem registrado em log.

## Instalação

### Pelo arquivo da release (recomendado)

Baixe o `.plasmoid` em [Releases](https://github.com/egionCode/plasma-github-issues/releases)
e instale:

```bash
kpackagetool6 -t Plasma/Applet -i github-issues-X.Y.Z.plasmoid   # primeira vez
kpackagetool6 -t Plasma/Applet -u github-issues-X.Y.Z.plasmoid   # atualizar
```

### A partir do código

```bash
git clone https://github.com/egionCode/plasma-github-issues
cd plasma-github-issues
kpackagetool6 -t Plasma/Applet -i com.egion.githubissues
```

Depois: clique direito no desktop ou painel, "Adicionar widgets", "GitHub Issues".
Para remover: `kpackagetool6 -t Plasma/Applet -r com.egion.githubissues`.

## Desenvolvimento

```bash
npm test                                                   # testes automatizados
plasmoidviewer -a ./com.egion.githubissues -f planar -s 560x1000   # testar numa janela
GH_TOKEN=invalido plasmoidviewer -a ./com.egion.githubissues      # ver o estado de erro
```

`plasmoidviewer` vem no pacote `plasma-sdk`. Para ver logs do QML use
`QT_FORCE_STDERR_LOGGING=1`.

### Estrutura

```
com.egion.githubissues/
  metadata.json
  contents/
    code/github.mjs   # lógica pura: URL, normalização, agrupamento, busca, diff, paginação
    code/http.mjs     # adaptador de XMLHttpRequest que devolve Promise
    config/           # main.xml (opções) e config.qml
    ui/               # main.qml, FullRepresentation, CompactRepresentation, delegates
tests/                # testes em Node + smoke test no motor QML real (qml6)
```

### Decisões não óbvias

- **Sem `async/await`:** o motor JS do QML (V4) não suporta a sintaxe e o módulo inteiro
  falha ao carregar. Usa-se Promises encadeadas. O teste `tests/qml-smoke.test.mjs` roda os
  módulos no `qml6` para pegar esse tipo de incompatibilidade, que o Node não detecta.
- **Sem `Object.fromEntries`:** também não existe no motor QML.
- **Notificação sem shell:** títulos de issue podem vir de terceiros (issues abertas em repos
  públicos), então o aviso usa `org.kde.notification` e nunca passa texto por um shell.
- **Padrão "Todas":** `assigned` costuma mostrar quase nada para quem trabalha sozinho.
- **Duas comparações distintas:** o destaque compara com o que você já viu (persistido na
  config); a notificação compara com a atualização anterior (memória), para avisar uma vez só.

## Limitações conhecidas

- Busca pelo endpoint `GET /issues`: só issues de repos aos quais o token tem acesso.
- Até 5 páginas de 100 issues por atualização.
- Em conta com orgs, o filtro "Todas" inclui itens assinados (`subscribed`) e pode trazer ruído.

## Licença

[MIT](LICENSE)
