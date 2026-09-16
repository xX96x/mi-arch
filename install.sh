#!/bin/bash
set -e

# Asegurar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Por favor ejecuta este script como root."
  exit 1
fi

echo "=========================================================="
echo "=== 0. SINCRONIZANDO RELOJ Y PREPARANDO LLAVES GPG ==="
echo "=========================================================="
# Sincronizar reloj para evitar firmas PGP marcadas como inválidas/expiradas
timedatectl set-ntp true 2>/dev/null || true

# Inyectar preventivamente la llave de CachyOS antes de cualquier sync
echo "[+] Importando llave pública de CachyOS en pacman-key..."
curl -sL https://raw.githubusercontent.com/cachyos-keyring/master/cachyos-keyring.gpg -o /tmp/cachyos-keyring.gpg
pacman-key --add /tmp/cachyos-keyring.gpg
pacman-key --lsign-key F3B607488BE3543F 2>/dev/null || true
rm -f /tmp/cachyos-keyring.gpg

# Si CachyOS ya estaba en pacman.conf o faltan mirrorlists, reinstalamos su repo limpiamente
if ! grep -q "cachyos" /etc/pacman.conf || [ ! -f /etc/pacman.d/cachyos-mirrorlist ]; then
    echo "[+] Configurando/Reparando repositorio oficial de CachyOS..."
    curl -s https://mirror.cachyos.org/cachyos-repo.tar.xz -o /tmp/cachyos-repo.tar.xz
    tar -xf /tmp/cachyos-repo.tar.xz -C /tmp/
    (cd /tmp/cachyos-repo && ./cachyos-repo.sh)
    rm -rf /tmp/cachyos-repo*
fi

echo "=========================================================="
echo "=== 1. PREPARATIVOS BÁSICOS Y USUARIO FABIARCH ==="
echo "=========================================================="
# Ahora pacman -Sy NUNCA fallará por firmas de CachyOS
pacman -Sy --noconfirm
pacman -S --needed --noconfirm git base-devel sudo paru octopi

if ! id "fabiarch" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash fabiarch
    echo "Asigna la contraseña para fabiarch:"
    passwd fabiarch
else
    echo "[+] El usuario fabiarch ya existe."
    usermod -aG wheel -s /bin/bash fabiarch
fi

echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel

echo "=========================================================="
echo "=== 2. INSTALANDO Y CONECTANDO CLOUDFLARE WARP ==="
echo "=========================================================="
if ! command -v warp-cli &> /dev/null; then
    echo "[+] Instalando cloudflare-warp-bin con paru..."
    sudo -u fabiarch paru -S --needed --noconfirm cloudflare-warp-bin
else
    echo "[+] Cloudflare Warp ya está instalado."
fi

systemctl enable --now warp-svc || true
sleep 2

echo "[+] Conectando a Cloudflare Warp..."
warp-cli --accept-tos registration new 2>/dev/null || true
warp-cli --accept-tos connect 2>/dev/null || true

sleep 3
warp-cli --accept-tos status || true

echo "=========================================================="
echo "=== 3. INSTALANDO PLASMA Y RESTO DEL SISTEMA (VÍA WARP) ==="
echo "=========================================================="
pacman -Syu --needed --noconfirm \
    plasma sddm networkmanager \
    dolphin firefox ark konsole \
    htop fastfetch btop

echo "=========================================================="
echo "=== 4. SERVICIOS Y PERMISOS FINALES ==="
echo "=========================================================="
systemctl enable NetworkManager || true
systemctl enable sddm || true

# Restaurar seguridad en sudoers (pedir contraseña)
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
chown -R fabiarch:fabiarch /home/fabiarch

echo "=========================================================="
echo "¡LISTO! Sistema desplegado sin errores de firmas y con Warp."
echo "=========================================================="
