#!/usr/bin/env bash

set -euo pipefail

readonly BASE="/opt/hosts-redirect"
readonly SRC="$BASE/src"
readonly WEB="$BASE/web"
readonly CERTS="$BASE/certs"
readonly SECRET="$BASE/secret"
readonly LOCALCA="$BASE/local-ca"
readonly LIST="$BASE/blocked-redirects.txt"
readonly GEN_SCRIPT="$BASE/rebuild_from_list.sh"
readonly C_RESET='\033[0m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_RED='\033[0;31m'

log_info() {
  echo -e "${C_BLUE}[INFO]${C_RESET} $1"
}

log_success() {
  echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_error() {
  echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

function check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Este script precisa ser executado como root. Use 'sudo'."
    exit 1
  fi
}

function install_dependencies() {
  log_info "Atualizando a lista de pacotes..."
  apt-get update -y
  log_info "Instalando dependências (default-jdk, openssl)..."
  apt-get install -y default-jdk ca-certificates openssl
}

function create_directories() {
  log_info "Criando estrutura de diretórios em $BASE..."
  mkdir -p "$SRC" "$WEB" "$CERTS" "$SECRET" "$LOCALCA"
  chmod 750 "$SECRET"
  chmod 700 "$LOCALCA"
}

function create_web_page() {
  log_info "Criando ou atualizando a página de bloqueio em $WEB/index.html..."
  tee "$WEB/index.html" >/dev/null <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Volta. Agora.</title>

  <style>
    :root{
      /* “Gran vibes”: azul + amarelo */
      --bg0:#070b14;
      --bg1:#0b1430;
      --card:rgba(255,255,255,.06);
      --border:rgba(255,255,255,.08);

      --text:#eaf1ff;
      --muted:#a9b6d3;

      --gran-blue:#1a71ff;
      --gran-yellow:#fce205;

      --danger:#ff3b3b;
      --shadow:rgba(0,0,0,.55);

      --btn:#1a71ff;
      --btnText:#ffffff;
      --btn2:#fce205;
      --btn2Text:#121212;
    }

    *{box-sizing:border-box}
    body{
      margin:0;
      min-height:100vh;
      font-family: Inter, system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif;
      color:var(--text);
      background:
        radial-gradient(1200px 600px at 20% 20%, rgba(26,113,255,.20), transparent 60%),
        radial-gradient(900px 500px at 80% 30%, rgba(252,226,5,.14), transparent 55%),
        radial-gradient(800px 500px at 50% 95%, rgba(255,59,59,.10), transparent 60%),
        linear-gradient(180deg, var(--bg0), var(--bg1));
      display:flex;
      align-items:center;
      justify-content:center;
      padding:22px;
      overflow:hidden;
      opacity:0;
      animation:fadeIn .55s ease-out forwards;
    }

    /* “Pressão” sutil */
    .vignette{
      position:fixed; inset:-40px;
      pointer-events:none;
      background:
        radial-gradient(closest-side at 50% 50%, transparent 0%, rgba(0,0,0,.55) 75%, rgba(0,0,0,.82) 100%);
      mix-blend-mode:multiply;
    }
    .scanline{
      position:fixed; inset:0;
      pointer-events:none;
      background: repeating-linear-gradient(
        to bottom,
        rgba(255,255,255,.03) 0px,
        rgba(255,255,255,.03) 1px,
        transparent 2px,
        transparent 6px
      );
      opacity:.10;
    }

    .wrap{
      width:100%;
      max-width:860px;
      position:relative;
    }

    .topbar{
      display:flex;
      gap:10px;
      align-items:center;
      justify-content:space-between;
      margin-bottom:14px;
      flex-wrap:wrap;
    }

    .badge{
      display:inline-flex;
      align-items:center;
      gap:10px;
      padding:10px 12px;
      border-radius:999px;
      background:rgba(255,59,59,.10);
      border:1px solid rgba(255,59,59,.28);
      color:#ffd7d7;
      font-weight:800;
      letter-spacing:.3px;
      box-shadow:0 10px 28px rgba(255,59,59,.08);
      animation:throb 1.6s ease-in-out infinite;
    }
    .dot{
      width:10px; height:10px; border-radius:50%;
      background:var(--danger);
      box-shadow:0 0 0 0 rgba(255,59,59,.55);
      animation:ping 1.3s ease-out infinite;
    }

    .method{
      display:inline-flex;
      align-items:center;
      gap:10px;
      padding:10px 12px;
      border-radius:999px;
      background:rgba(252,226,5,.12);
      border:1px solid rgba(252,226,5,.28);
      color:#fff6b6;
      font-weight:900;
      letter-spacing:.2px;
    }
    .method strong{
      color:var(--gran-yellow);
      text-shadow:0 0 18px rgba(252,226,5,.14);
    }

    .card{
      background:var(--card);
      border:1px solid var(--border);
      border-radius:18px;
      box-shadow:0 18px 50px var(--shadow);
      padding:28px;
      position:relative;
      overflow:hidden;
      transform:translateY(10px) scale(.98);
      opacity:0;
      animation:enter .65s ease-out .05s forwards;
    }

    .card::before{
      content:"";
      position:absolute; inset:-2px;
      background:
        radial-gradient(600px 180px at 10% 0%, rgba(26,113,255,.25), transparent 60%),
        radial-gradient(520px 180px at 90% 0%, rgba(252,226,5,.18), transparent 60%),
        radial-gradient(520px 200px at 50% 100%, rgba(255,59,59,.10), transparent 65%);
      pointer-events:none;
      filter:blur(2px);
      opacity:.9;
    }

    .content{ position:relative; z-index:1; }

    h1{
      margin:0 0 10px;
      font-size:40px;
      line-height:1.06;
      letter-spacing:-.6px;
      font-weight:950;
    }
    h1 .y{ color:var(--gran-yellow); }
    h1 .b{ color:var(--gran-blue); }
    h1 .d{ color:#ffb3b3; }

    .subtitle{
      margin:0 0 18px;
      font-size:18px;
      line-height:1.55;
      color:var(--muted);
    }

    .warning{
      margin:16px 0 18px;
      padding:14px 14px;
      border-radius:14px;
      background:rgba(255,59,59,.09);
      border:1px solid rgba(255,59,59,.22);
      color:#ffd5d5;
    }
    .warning strong{ color:#ffffff; }

    .grid{
      display:grid;
      grid-template-columns:1.2fr .8fr;
      gap:14px;
      margin:14px 0 18px;
    }
    @media (max-width: 860px){
      h1{ font-size:34px; }
      .grid{ grid-template-columns:1fr; }
    }

    .panel{
      background:rgba(0,0,0,.18);
      border:1px solid rgba(255,255,255,.08);
      border-radius:14px;
      padding:14px;
    }
    .panel h2{
      margin:0 0 10px;
      font-size:15px;
      letter-spacing:.4px;
      text-transform:uppercase;
      color:#dfe9ff;
      opacity:.95;
    }

    .facts{
      margin:0;
      padding-left:18px;
      color:#cfdaf3;
      line-height:1.55;
      font-size:15.5px;
    }
    .facts li{ margin:8px 0; }
    .facts em{ color:var(--gran-yellow); font-style:normal; font-weight:900; }

    .timer{
      display:flex;
      flex-direction:column;
      gap:10px;
    }
    .big{
      font-size:14px;
      color:#dbe6ff;
      opacity:.95;
    }
    .count{
      font-variant-numeric: tabular-nums;
      display:flex;
      gap:10px;
      flex-wrap:wrap;
    }
    .pill{
      padding:10px 12px;
      border-radius:12px;
      border:1px solid rgba(255,255,255,.10);
      background:rgba(255,255,255,.05);
      min-width:120px;
      text-align:center;
      box-shadow:0 10px 20px rgba(0,0,0,.18);
    }
    .pill .n{
      display:block;
      font-size:26px;
      font-weight:950;
      color:#ffffff;
    }
    .pill .t{
      display:block;
      font-size:12px;
      color:var(--muted);
      margin-top:2px;
      letter-spacing:.3px;
      text-transform:uppercase;
    }

    .actions{
      display:flex;
      gap:12px;
      justify-content:center;
      flex-wrap:wrap;
      margin-top:16px;
    }
    a.btn{
      display:inline-flex;
      align-items:center;
      justify-content:center;
      gap:10px;
      padding:14px 18px;
      border-radius:14px;
      text-decoration:none;
      font-weight:900;
      letter-spacing:.2px;
      transition:transform .18s ease, filter .18s ease, box-shadow .18s ease;
      border:1px solid rgba(255,255,255,.10);
      user-select:none;
    }
    .btn.primary{
      background:linear-gradient(180deg, rgba(26,113,255,1), rgba(26,113,255,.85));
      color:var(--btnText);
      box-shadow:0 14px 30px rgba(26,113,255,.25);
    }
    .btn.secondary{
      background:linear-gradient(180deg, rgba(252,226,5,1), rgba(252,226,5,.86));
      color:var(--btn2Text);
      box-shadow:0 14px 30px rgba(252,226,5,.18);
    }
    a.btn:hover{
      transform:translateY(-2px) scale(1.02);
      filter:saturate(1.05);
    }

    .footer{
      margin-top:14px;
      text-align:center;
      font-size:13px;
      color:rgba(233,242,255,.70);
      line-height:1.5;
    }
    .footer code{
      padding:2px 6px;
      border-radius:8px;
      border:1px solid rgba(255,255,255,.10);
      background:rgba(0,0,0,.18);
      color:#eaf1ff;
      font-weight:800;
    }

    body.exit-animation{ animation:fadeOutZoom .55s ease-in forwards; }

    @keyframes fadeIn{ to{ opacity:1 } }
    @keyframes enter{ to{ opacity:1; transform:translateY(0) scale(1) } }
    @keyframes fadeOutZoom{ from{opacity:1; transform:scale(1)} to{opacity:0; transform:scale(.86)} }
    @keyframes ping{
      0%{ box-shadow:0 0 0 0 rgba(255,59,59,.55) }
      70%{ box-shadow:0 0 0 14px rgba(255,59,59,0) }
      100%{ box-shadow:0 0 0 0 rgba(255,59,59,0) }
    }
    @keyframes throb{
      0%,100%{ transform:translateZ(0) scale(1) }
      50%{ transform:translateZ(0) scale(1.02) }
    }
  </style>
</head>

<body>
  <div class="vignette"></div>
  <div class="scanline"></div>

  <div class="wrap">
    <div class="topbar">
      <div class="badge"><span class="dot"></span> ALERTA DE DESVIO</div>
      <div class="method">Método <strong>01</strong> vai dar certo.</div>
    </div>

    <div class="card">
      <div class="content">
        <h1><span class="y">Pare.</span> <span class="b">Agora.</span> <span class="d">Volte pro estudo.</span></h1>

        <p class="subtitle">
          Esse clique “inofensivo” é como você <strong>perdendo sua vaga por minutos</strong>.
          O edital não perdoa. O tempo não volta. E ninguém vai estudar por você.
        </p>

        <div class="warning">
          <strong>Realidade:</strong> distração não é descanso — é dívida.
          Você paga depois com ansiedade, pressa, culpa e prova mal feita.
        </div>

        <div class="grid">
          <div class="panel">
            <h2>Se você continuar aqui…</h2>
            <ul class="facts">
              <li>Você treina o cérebro a buscar alívio rápido — e <em>piora a disciplina</em>.</li>
              <li>Você troca futuro por dopamina barata — e depois chama isso de “cansaço”.</li>
              <li>Você adia hoje e empilha amanhã — <em>e amanhã chega com juros</em>.</li>
              <li>Você diz “só 5 minutos” — e entrega <em>30, 60, 90…</em></li>
            </ul>
          </div>

          <div class="panel timer">
            <h2>Seu foco começa em</h2>
            <div class="big">
              25 minutos de execução > 2 horas de “planejamento”.<br>
              Comece um bloco. Agora.
            </div>

            <div class="count" aria-label="contador">
              <div class="pill"><span class="n" id="m">25</span><span class="t">minutos</span></div>
              <div class="pill"><span class="n" id="s">00</span><span class="t">segundos</span></div>
            </div>

            <div class="big">
              Regra: abre o Gran e resolve <strong>10 questões</strong> antes de qualquer outra coisa.
            </div>
          </div>
        </div>

        <div class="actions">
          <a class="btn primary" id="goGran" href="https://www.grancursosonline.com.br/" target="_blank" rel="noopener">
            📘 Abrir Gran (AGORA)
          </a>

          <a class="btn secondary" id="goQuestoes" href="https://questoes.grancursosonline.com.br/" target="_blank" rel="noopener">
            ✅ Ir direto pras Questões
          </a>
        </div>

        <div class="footer">
          Lembrete duro, mas verdadeiro: estabilidade não cai do céu.
          <br>
          <code>Bloco 25/5</code> — 25 min foco total + 5 min pausa. Repete.
        </div>
      </div>
    </div>
  </div>

  <script>
    // Pomodoro visual (25:00 -> 00:00)
    let total = 25 * 60; // segundos
    const elM = document.getElementById('m');
    const elS = document.getElementById('s');

    function tick(){
      const m = Math.floor(total / 60);
      const s = total % 60;
      elM.textContent = String(m).padStart(2,'0');
      elS.textContent = String(s).padStart(2,'0');

      if(total > 0){
        total--;
      }else{
        // quando zera: aumenta pressão visual no alerta
        const badge = document.querySelector('.badge');
        badge.style.borderColor = 'rgba(252,226,5,.45)';
        badge.style.background = 'rgba(252,226,5,.12)';
        badge.style.color = '#fff6b6';
        document.querySelector('.badge .dot').style.background = 'var(--gran-yellow)';
      }
    }
    tick();
    setInterval(tick, 1000);

    function openWithExit(url){
      document.body.classList.add('exit-animation');
      setTimeout(() => window.open(url, '_blank'), 350);
    }

    document.getElementById('goGran').addEventListener('click', (e) => {
      e.preventDefault();
      openWithExit('https://www.grancursosonline.com.br/');
    });

    document.getElementById('goQuestoes').addEventListener('click', (e) => {
      e.preventDefault();
      openWithExit('https://questoes.grancursosonline.com.br/');
    });
  </script>
</body>
</html>
HTML
}

function create_block_list() {
  if [ ! -f "$LIST" ]; then
    log_info "Criando lista de bloqueio padrão em $LIST..."
    tee "$LIST" >/dev/null <<'EOF'
# -----------------
# REDES SOCIAIS E VÍDEOS
# -----------------
youtube.com
www.youtube.com
m.youtube.com
facebook.com
www.facebook.com
instagram.com
www.instagram.com
twitter.com
www.twitter.com
x.com
www.x.com
tiktok.com
www.tiktok.com
reddit.com
www.reddit.com
linkedin.com
www.linkedin.com
pinterest.com
www.pinterest.com
br.pinterest.com
twitch.tv
www.twitch.tv
kwai.com
www.kwai.com

# -----------------
# NOTÍCIAS NACIONAIS
# -----------------
g1.globo.com
www.g1.globo.com
oglobo.globo.com
www.oglobo.globo.com
valor.globo.com
uol.com.br
www.uol.com.br
noticias.uol.com.br
folha.uol.com.br
www.folha.uol.com.br
terra.com.br
www.terra.com.br
r7.com
www.r7.com
noticias.r7.com
estadao.com.br
www.estadao.com.br
metropoles.com
www.metropoles.com
cnnbrasil.com.br
www.cnnbrasil.com.br
poder360.com.br
www.poder360.com.br
jovempan.com.br
noticias.jovempan.com.br
band.uol.com.br/noticias
veja.abril.com.br
exame.com
cartacapital.com.br
oantagonista.com
brasil247.com

# -----------------
# ESPORTES
# -----------------
ge.globo.com
www.ge.globo.com
globoesporte.globo.com
esporte.uol.com.br
esportes.terra.com.br
esportes.r7.com
espn.com.br
www.espn.com.br
lance.com.br
www.lance.com.br
placar.com.br
gazetaesportiva.com
bandsports.com.br
esporte.band.uol.com.br

# -----------------
# AGREGADORES E OUTROS
# -----------------
br.noticias.yahoo.com
news.google.com

EOF
  fi
}

function create_java_server() {
  log_info "Criando o código-fonte do servidor Java..."
  tee "$SRC/HttpsFocusServer.java" >/dev/null <<'JAVA'
import com.sun.net.httpserver.*;
import javax.net.ssl.*;
import java.io.*;
import java.net.InetSocketAddress;
import java.nio.file.*;
import java.security.*;

public class HttpsFocusServer {
    public static void main(String[] args) {
        try {
            if (args.length < 3) {
                System.err.println("Uso: HttpsFocusServer <PORTA> <CAMINHO_P12> <SENHA> [WEB_ROOT]");
                System.exit(1);
            }
            int port = Integer.parseInt(args[0]);
            Path p12Path = Paths.get(args[1]);
            char[] password = args[2].toCharArray();
            Path webRoot = Paths.get(args.length == 4 ? args[3] : "/opt/hosts-redirect/web");

            if (!Files.exists(p12Path)) throw new FileNotFoundException("Arquivo P12 não encontrado: " + p12Path);
            if (!Files.isDirectory(webRoot)) throw new FileNotFoundException("Diretório web_root não encontrado: " + webRoot);

            KeyStore ks = KeyStore.getInstance("PKCS12");
            try (InputStream is = Files.newInputStream(p12Path)) { ks.load(is, password); }

            KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            kmf.init(ks, password);

            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(kmf.getKeyManagers(), null, new SecureRandom());

            HttpsServer server = HttpsServer.create(new InetSocketAddress("::", port), 0);
            server.setHttpsConfigurator(new HttpsConfigurator(sslContext));
            server.createContext("/", exchange -> {
                try {
                    byte[] response = Files.readAllBytes(webRoot.resolve("index.html"));
                    exchange.getResponseHeaders().add("Content-Type", "text/html; charset=utf-8");
                    exchange.getResponseHeaders().add("Cache-Control", "no-store");
                    exchange.sendResponseHeaders(200, response.length);
                    try (OutputStream os = exchange.getResponseBody()) { os.write(response); }
                } catch (IOException e) {
                    byte[] errorResponse = ("Erro interno: " + e.getMessage()).getBytes();
                    exchange.sendResponseHeaders(500, errorResponse.length);
                    try (OutputStream os = exchange.getResponseBody()) { os.write(errorResponse); }
                } finally {
                    exchange.close();
                }
            });
            server.setExecutor(null);
            System.out.println("Servidor HTTPS de Foco iniciado na porta " + port);
            server.start();
        } catch (Exception e) {
            System.err.println("Falha fatal ao iniciar o servidor: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
JAVA
}

function create_rebuild_script() {
  log_info "Criando o script de regeneração de hosts e certificados..."
  tee "$GEN_SCRIPT" >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/hosts-redirect"
LIST="$BASE/blocked-redirects.txt"
LOCALCA="$BASE/local-ca"
OPENSSL_CNF="$LOCALCA/openssl.cnf"
CERTS="$BASE/certs"
SECRET="$BASE/secret"
P12="$CERTS/server.p12"
PASSFILE="$SECRET/p12.pass"
HOSTS_BEGIN="# BEGIN HOSTS-REDIRECTOR (managed by script)"
HOSTS_END="# END HOSTS-REDIRECTOR"

echo "==== Iniciando Regeneração de Hosts/Certificados ===="
mkdir -p "$LOCALCA" "$CERTS" "$SECRET"; chmod 750 "$SECRET"; chmod 700 "$LOCALCA"

if [ ! -s "$LIST" ]; then
  echo "  [WARN] Lista de bloqueio $LIST está vazia. Limpando /etc/hosts."
  if grep -qF "$HOSTS_BEGIN" /etc/hosts; then
      sed -i.bak "/$HOSTS_BEGIN/,/$HOSTS_END/d" /etc/hosts
  fi
  exit 0
fi

DOMAINS=()
while IFS= read -r line; do
  domain=$(echo "$line" | sed 's/#.*//; s/^\s*//; s/\s*$//')
  [ -n "$domain" ] && DOMAINS+=("$domain")
done < "$LIST"

if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo "  [WARN] Nenhum domínio válido encontrado. Nada a fazer."
    exit 0
fi
echo "  [INFO] Encontrados ${#DOMAINS[@]} domínios para processar."

echo "  [INFO] Gerando configuração OpenSSL..."
cat > "$OPENSSL_CNF" <<EOF
[ req ]
distinguished_name  = dn
req_extensions      = v3_req
[ dn ]
CN = Localhost Redirector
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
EOF
i=1
for d in "${DOMAINS[@]}"; do
  echo "DNS.$i = $d" >> "$OPENSSL_CNF"
  i=$((i+1))
done

if [ ! -f "$LOCALCA/localCA.key" ]; then
  echo "  [INFO] Criando nova Autoridade Certificadora (CA) local..."
  openssl genrsa -out "$LOCALCA/localCA.key" 4096
  openssl req -x509 -new -nodes -key "$LOCALCA/localCA.key" -sha256 -days 3650 \
    -out "$LOCALCA/localCA.crt" -subj "/C=BR/O=LocalCA/CN=Local Root CA"
  echo "  [INFO] Instalando CA no sistema..."
  cp "$LOCALCA/localCA.crt" /usr/local/share/ca-certificates/
  update-ca-certificates
fi

echo "  [INFO] Gerando novo certificado de servidor para os domínios..."
openssl genrsa -out "$CERTS/server.key" 2048
openssl req -new -key "$CERTS/server.key" -out "$CERTS/server.csr" -config "$OPENSSL_CNF" -subj "/CN=Localhost Redirector"
openssl x509 -req -in "$CERTS/server.csr" -CA "$LOCALCA/localCA.crt" -CAkey "$LOCALCA/localCA.key" \
  -CAcreateserial -out "$CERTS/server.crt" -days 730 -sha256 -extfile "$OPENSSL_CNF" -extensions v3_req

if [ ! -f "$PASSFILE" ]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 > "$PASSFILE"
  chmod 600 "$PASSFILE"
fi
openssl pkcs12 -export -inkey "$CERTS/server.key" -in "$CERTS/server.crt" \
  -name hosts-redirector -out "$P12" -passout file:"$PASSFILE"

echo "  [INFO] Atualizando /etc/hosts..."
sed -i.bak "/$HOSTS_BEGIN/,/$HOSTS_END/d" /etc/hosts
{
  echo "$HOSTS_BEGIN"
  for d in "${DOMAINS[@]}"; do
    echo "127.0.0.1 $d"; echo "::1       $d";
  done
  echo "$HOSTS_END"
} >> /etc/hosts
chmod 644 /etc/hosts

echo "  [INFO] Recompilando o servidor Java (se necessário)..."
javac "$BASE/src/HttpsFocusServer.java"
echo "  [INFO] Sinalizando para o systemd reiniciar o serviço..."
systemctl restart https-focus.service
echo "==== Regeneração Concluída ===="
BASH
  chmod +x "$GEN_SCRIPT"
}

function create_systemd_units() {
  log_info "Criando e configurando os serviços do systemd..."

  tee "/etc/systemd/system/https-focus.service" >/dev/null <<SERVICE
[Unit]
Description=HTTPS Focus Server (Java)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BASE
ExecStart=/bin/bash -lc '/usr/bin/java -cp $SRC HttpsFocusServer 443 $CERTS/server.p12 "\$(cat $SECRET/p12.pass)" $WEB'
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/https-focus.log
StandardError=append:/var/log/https-focus.log

[Install]
WantedBy=multi-user.target
SERVICE

  tee "/etc/systemd/system/hosts-redirector-reload.service" >/dev/null <<RELOADSVC
[Unit]
Description=Rebuild certificate/hosts from block list

[Service]
Type=oneshot
ExecStart=$GEN_SCRIPT
RELOADSVC

  tee "/etc/systemd/system/hosts-redirector-reload.path" >/dev/null <<RELOADPATH
[Unit]
Description=Watch block list for changes

[Path]
PathChanged=$LIST
Unit=hosts-redirector-reload.service

[Install]
WantedBy=multi-user.target
RELOADPATH
}

function run_first_build_and_enable() {
  log_info "Compilando o servidor Java pela primeira vez..."
  javac "$SRC/HttpsFocusServer.java"

  log_info "Executando a primeira geração de hosts e certificados..."
  "$GEN_SCRIPT"

  log_info "Habilitando e iniciando os serviços..."
  systemctl daemon-reload
  systemctl enable --now https-focus.service
  systemctl enable --now hosts-redirector-reload.path
}

main() {
  check_root

  install_dependencies
  create_directories
  create_web_page
  create_block_list
  create_java_server
  create_rebuild_script
  create_systemd_units

  run_first_build_and_enable

  echo
  log_success "=== INSTALAÇÃO CONCLUÍDA ==="
  echo "O sistema de foco está ativo e iniciará com o sistema."
  echo
  echo -e "Para editar os sites bloqueados, modifique o arquivo:"
  echo -e "  ${C_YELLOW}$LIST${C_RESET}"
  echo
  echo "As mudanças serão aplicadas automaticamente ao salvar o arquivo."
  echo "Para verificar o status, use: ${C_YELLOW}systemctl status https-focus.service${C_RESET}"
  echo "Logs do servidor estão em: ${C_YELLOW}/var/log/https-focus.log${C_RESET}"
}

main "$@"
