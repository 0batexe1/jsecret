#!/usr/bin/env bash
set -euo pipefail

# jsecret.sh - Gelişmiş secret / sensitive extractor (Türkçe)
# Not: Bu script ham veriler üretir. Çıktılar hassas olabilir. Dikkatli kullan.

# RENKLER
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  cat <<EOF
${BOLD}KULLANIM${NC}:
  Tek dosya/URL tarama:
    ${GREEN}./jsecret.sh hedef.js${NC}
    ${GREEN}./jsecret.sh https://example.com/app.js${NC}

  Targets listesi (.txt, her satır bir hedef):
    ${GREEN}./jsecret.sh targets.txt${NC}

  Diff modu (önceki bulgularla karşılaştırma):
    ${GREEN}./jsecret.sh targets.txt --diff=true${NC}

NOT:
  - Tüm bulgular maskesiz (cleartext) olarak kaydedilir.
  - Önceki taramalar 'onceki_bulgular/' altında saklanır.
EOF
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

INPUT="$1"
DIFF_FLAG="${2:---diff=false}"

# OUTPUT KLASÖR (anlaşılır)
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
OUT_DIR="bulgular_${TIMESTAMP}"
mkdir -p "$OUT_DIR/orijinler"
mkdir -p "onceki_bulgular"

echo -e "${BLUE}${BOLD}== Secret Extractor Başlıyor ==${NC}"
echo -e "Girdi: ${GREEN}$INPUT${NC}    Diff: ${YELLOW}$DIFF_FLAG${NC}"
echo -e "Çıktı dizini: ${GREEN}$OUT_DIR/${NC}"
echo

# LOCAL FILES array
LOCAL_FILES=()

download_or_copy() {
  local src="$1"
  local dst_dir="$2"
  mkdir -p "$dst_dir"

  local out
  if [[ "$src" =~ ^https?:// ]]; then
    local base="$(basename "${src%/}")"
    if [[ -z "$base" || "$base" == "$src" ]]; then
      base="$(echo "$src" | sed -E 's#https?://##' | sed -E 's#/+#_#g' | sed -E 's#[^A-Za-z0-9_.-]#_#g').js"
    fi
    out="$dst_dir/$base"
    echo -e "${YELLOW}İndiriliyor:${NC} $src -> $out"
    if ! curl -sS -L --max-time 30 -o "$out" "$src"; then
      echo -e "${RED}Hata:${NC} $src indirilemedi."
      return 1
    fi
    local sz=$(stat -c%s "$out" 2>/dev/null || echo 0)
    if [[ $sz -lt 20 ]]; then
      echo -e "${YELLOW}Uyarı:${NC} İndirilen dosya küçük/şüpheli ($sz byte)."
    fi
  else
    if [[ -f "$src" ]]; then
      local base="$(basename "$src")"
      out="$dst_dir/$base"
      cp "$src" "$out"
      echo -e "${YELLOW}Kopyalandı:${NC} $src -> $out"
    else
      echo -e "${RED}Hata:${NC} Yerel dosya bulunamadı: $src"
      return 1
    fi
  fi
  LOCAL_FILES+=("$out")
  return 0
}

INPUTS=()
if [[ -f "$INPUT" ]]; then
  if [[ "$INPUT" =~ \.txt$ ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -z "$line" ]] && continue
      INPUTS+=("$line")
    done < "$INPUT"
  else
    INPUTS+=("$INPUT")
  fi
else
  INPUTS+=("$INPUT")
fi

for tgt in "${INPUTS[@]}"; do
  tgt="$(echo "$tgt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$tgt" ]] && continue
  download_or_copy "$tgt" "$OUT_DIR/orijinler" || true
done

if [[ ${#LOCAL_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}Hata:${NC} İşlenecek dosya yok. Çıkış yapılıyor."
  exit 1
fi

echo
echo -e "${CYAN}İşlenecek yerel dosyalar:${NC}"
printf '%s\n' "${LOCAL_FILES[@]}"
echo

PAT_NAMES=(
  "anahtar_kelime"
  "uzun_rastgele"
  "jwt"
  "url"
  "dahili_host"
  "aws_akid"
  "aws_secret"
  "google_api"
  "stripe_pk"
  "slack_hook"
  "sendgrid"
  "mailgun"
  "github_token"
  "firebase"
  "oauth_token"
  "session_cookie"
  "email"
  "phone"
  "pem_private_key"
  "ssh_private_key"
  "db_connection"
  "basic_auth"
)

PAT_REGEX=(
  '(?i)\b(api[_-]?key|apikey|client[_-]?secret|secret[_-]?key|access[_-]?token|auth|authorization|bearer|jwt|private[_-]?key|aws_secret|aws_access_key|S3_BUCKET|sendgrid|stripe|mailgun|slack|webhook|firebase|gcp|google[_-]?api|ghp_[A-Za-z0-9_]+|xox[baprs]-[A-Za-z0-9-]+)\b'
  '([A-Za-z0-9_\-]{30,})'
  '\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'
  '(https?:\/\/|\/\/)[^"'\''\)\s]+'
  '\b(localhost|127\.0\.0\.1|10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|internal|staging|dev|admin|qa|test)\b'
  'AKIA[0-9A-Z]{16}'
  '(?i)(aws_secret_access_key|aws_secret|aws_secret_key|aws_secret_access_key).{0,200}'
  'AIza[0-9A-Za-z\-_]{35}'
  'pk_(live|test)_[A-Za-z0-9_]+'
  'hooks.slack.com/services/[A-Za-z0-9/_-]+'
  '(?i)sendgrid(_|\.|-)api(_|\.|-)key|SG\.[A-Za-z0-9\-_]{16,}'
  '(?i)mailgun|mg\.api|mailgun_api_key|key-(live|test)?[A-Za-z0-9-_]{8,}'
  '(?i)(ghp_[A-Za-z0-9_]{36,}|github[_-]?token|GITHUB_TOKEN)'
  '(?i)(google_api_key|firebase|firebaseConfig|projectId|apiKey|FB_APP_SECRET)'
  '(?i)access_token|refresh_token|oauth_token|oauth_access_token|xox[baprs]-[A-Za-z0-9-]+'
  '(?i)(session|sess|PHPSESSID|connect.sid|sid|session_id)[=:"][A-Za-z0-9\-_\.]{8,}'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}'
  '(\+?\d{7,15}|\(\d{2,6}\)\s?\d{4,12})'
  '-----BEGIN (RSA )?PRIVATE KEY-----|-----BEGIN OPENSSH PRIVATE KEY-----|-----BEGIN DSA PRIVATE KEY-----|-----BEGIN EC PRIVATE KEY-----'
  '(^|\s)-----BEGIN OPENSSH PRIVATE KEY-----(.|\n){1,500}-----END OPENSSH PRIVATE KEY-----'
  '(?i)(ssh-rsa|ssh-ed25519|BEGIN RSA PRIVATE KEY|PRIVATE KEY|DSA PRIVATE KEY)'
  '(?i)(postgres:\/\/|postgresql:\/\/|mongodb:\/\/|mysql:\/\/|mssql:\/\/|redis:\/\/|jdbc:|Server=.*;Database=.*;User Id=.*;Password=.*;)'
  '(?i)Basic\s+[A-Za-z0-9=:+/._-]{10,}'
)

DECODE_TMP="$OUT_DIR/decoded_extra.txt"
> "$DECODE_TMP"

echo -e "${BLUE}Obfuscation tespiti ve base64 çözücü çalışıyor...${NC}"
MERGE_FILE="$OUT_DIR/tum_input_birlesik.js"
> "$MERGE_FILE"
for f in "${LOCAL_FILES[@]}"; do
  echo -e "\n/* ==== FILE: $f ==== */" >> "$MERGE_FILE"
  cat "$f" >> "$MERGE_FILE"
done

# Base64 decode
for pattern in '[A-Za-z0-9+/]{40,}={0,2}' '[A-Za-z0-9_-]{40,}={0,2}'; do
  grep -Pao "$pattern" "$MERGE_FILE" 2>/dev/null | sort -u | while read -r s; do
    conv="$s"
    if [[ "$pattern" == '[A-Za-z0-9_-]{40,}={0,2}' ]]; then
      conv=$(echo "$s" | tr '_-' '/+')
      rem=$(( ${#conv} % 4 ))
      [[ $rem -ne 0 ]] && conv="${conv}$(printf '%*s' $((4-rem)) | tr ' ' '=')"
    fi
    if echo "$conv" | base64 -d >/dev/null 2>&1; then
      echo "$conv" | base64 -d >> "$DECODE_TMP" 2>/dev/null || true
    fi
  done
done

[[ -s "$DECODE_TMP" ]] && echo -e "${GREEN}Base64 decode edildi; decode edilen içerik taramaya eklendi.${NC}" && echo -e "\n/* ==== DECODED CONTENTS ==== */" >> "$MERGE_FILE" && cat "$DECODE_TMP" >> "$MERGE_FILE" || echo -e "${YELLOW}Base64 decode ile ek içerik bulunmadı.${NC}"

WORKFILE="$MERGE_FILE"

# Regex tarama
echo
echo -e "${BLUE}Regex taraması başlıyor...${NC}"
for idx in "${!PAT_NAMES[@]}"; do
  name="${PAT_NAMES[$idx]}"
  regex="${PAT_REGEX[$idx]}"
  out_raw="$OUT_DIR/${name}_raw.txt"
  out_ctx="$OUT_DIR/${name}_context.txt"
  > "$out_raw"
  > "$out_ctx"

  echo -n "  * ${BOLD}$name${NC} ... "

  if grep -Pao "$regex" "$WORKFILE" 2>/dev/null; then
    grep -Pao "$regex" "$WORKFILE" | sort -u > "$out_raw" || true
    grep -an -iP "$regex" "$WORKFILE" | sed -n '1,500p' > "$out_ctx" || true
  else
    grep -iaoE "$regex" "$WORKFILE" | sort -u > "$out_raw" || true
    grep -ian -iE "$regex" "$WORKFILE" | sed -n '1,500p' > "$out_ctx" || true
  fi

  if [[ -s "$out_raw" ]]; then
    echo -e "${GREEN}bulundu ($(wc -l < "$out_raw") adet)${NC}"
  else
    echo -e "${YELLOW}yok${NC}"
    rm -f "$out_raw" "$out_ctx" 2>/dev/null || true
  fi
done

# DIFF
if [[ "$DIFF_FLAG" == "--diff=true" ]]; then
  echo
  echo -e "${BLUE}--diff etkin: onceki_bulgular/ içinden en son klasör aranacak...${NC}"
  LATEST_PREV=$(ls -1d onceki_bulgular/* 2>/dev/null | sort -r | head -n1 || true)
  if [[ -z "$LATEST_PREV" ]]; then
    echo -e "${YELLOW}Onceki bulgular bulunamadı. --diff atlandı.${NC}"
  else
    echo -e "Önceki klasör: ${GREEN}$LATEST_PREV${NC}"
    for name in "${PAT_NAMES[@]}"; do
      newf="$OUT_DIR/${name}_raw.txt"
      oldf="$LATEST_PREV/${name}_raw.txt"
      if [[ -f "$newf" && -f "$oldf" ]]; then
        comm -23 <(sort "$newf") <(sort "$oldf") > "$OUT_DIR/${name}_yeni.txt" || true
        [[ -s "$OUT_DIR/${name}_yeni.txt" ]] && echo -e "${GREEN}${name}: yeni $(wc -l < "$OUT_DIR/${name}_yeni.txt") adet${NC}"
      elif [[ -f "$newf" && ! -f "$oldf" ]]; then
        echo -e "${GREEN}${name}: tamamen yeni kategori, $(wc -l < "$newf") adet${NC}"
      fi
    done
  fi
fi

# Özet
echo
echo -e "${BOLD}${BLUE}== Tarama Özeti (HAM / Maskesiz) ==${NC}"
total=0
for f in "$OUT_DIR"/*_raw.txt; do
  [[ -s "$f" ]] || continue
  n=$(wc -l < "$f")
  total=$((total+n))
  echo -e "${CYAN}$(basename "$f"):${NC} ${GREEN}$n${NC}"
  echo "  Örnek (ilk 5):"
  sed -n '1,5p' "$f" | sed -e 's/^/    /'
done
echo
echo -e "${BOLD}Toplam bulunan öğe sayısı:${NC} ${BOLD}${total}${NC}"

echo
echo -e "${BLUE}Context örnekleri (her pattern için ilk satırlar):${NC}"
for f in "$OUT_DIR"/*_context.txt; do
  [[ -s "$f" ]] || continue
  echo -e "${CYAN}$(basename "$f"):${NC}"
  sed -n '1,5p' "$f" | sed -e 's/^/    /'
done

cp -r "$OUT_DIR" "onceki_bulgular/$OUT_DIR" || true

echo
echo -e "${GREEN}Tüm ham bulgular kaydedildi: ${BOLD}$OUT_DIR/${NC}"
[[ "$DIFF_FLAG" == "--diff=true" ]] && echo -e "${CYAN}Onceki bulgular dizini: onceki_bulgular/${NC}"

echo
echo -e "${BOLD}${GREEN}İŞLEM TAMAMLANDI.${NC}"
