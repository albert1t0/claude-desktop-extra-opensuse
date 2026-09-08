# Claude Desktop Extra para openSUSE

Herramientas para producir un RPM compatible con openSUSE a partir del
paquete comunitario [`claude-desktop-extra`](https://github.com/patrickjaja/claude-desktop-extra).

El RPM upstream está dirigido principalmente a Fedora/RHEL y declara nombres
como `mesa-libgbm` y `libdrm`. En openSUSE, las bibliotecas equivalentes se
publican como `libgbm1` y `libdrm2`. Este proyecto ofrece dos rutas:

1. **Conversión rápida:** extrae un RPM existente y lo reempaqueta sin tocar su
   contenido, sustituyendo sus dependencias por nombres openSUSE.
2. **Construcción nativa:** construye el RPM directamente desde el tarball
   upstream mediante un spec mantenible.

Ambas rutas producen un RPM nuevo, no instalan nada y nunca usan `--nodeps`.

## Decisiones de diseño

- **Dos rutas complementarias:** el reempaquetado resuelve rápidamente un RPM
  publicado; el spec nativo permite reconstruir desde el tarball upstream sin
  depender de un RPM Fedora ya generado.
- **Contenido Electron intacto:** solo se modifica la metadata RPM, la
  integración del escritorio y los nombres de dependencias del host.
- **Dependencias explícitas:** se desactiva el escaneo automático dentro de
  `/usr/lib/claude-desktop` porque ese árbol contiene bibliotecas bundled; las
  dependencias del sistema se declaran con nombres openSUSE.
- **Sin privilegios implícitos:** construir, convertir y validar no requiere
  root; la instalación se realiza únicamente mediante un comando explícito.
- **Verificación antes de construir:** el conversor admite checksum SHA-256
  opcional y ambos flujos validan arquitectura, versión y archivos críticos.

El objetivo no es publicar un repositorio openSUSE ni firmar paquetes
automáticamente. La firma y la instalación deben gestionarse por separado,
según la política del sistema que vaya a consumir el RPM.

## Releases automáticas (GitHub Actions)

Este repositorio publica RPMs openSUSE (`x86_64`) como
[GitHub Releases](https://github.com/albert1t0/claude-desktop-extra-opensuse/releases)
cuando aparece una versión nueva en
[`patrickjaja/claude-desktop-extra`](https://github.com/patrickjaja/claude-desktop-extra/releases).

El workflow [`.github/workflows/upstream-release.yml`](.github/workflows/upstream-release.yml):

- se ejecuta cada 6 horas y también se puede lanzar a mano (`workflow_dispatch`);
- toma el tag más reciente del origen (o un tag concreto si lo indicas);
- omite el trabajo si este repo ya tiene una release con el mismo tag;
- descarga el tarball `claude-desktop-VERSION-linux.tar.gz`, exige y verifica el
  digest SHA-256 del asset upstream (falla si falta), construye el RPM con
  `scripts/build-rpm-opensuse.sh` y lo valida;
- publica el RPM y `rpm-info.txt` en una release con el mismo tag upstream
  (por ejemplo `v1.46388.2-3` → `claude-desktop-extra-1.46388.2-opensuse3.x86_64.rpm`).

Para forzar un tag concreto: en GitHub → **Actions** → **Upstream openSUSE RPM
release** → **Run workflow** → campo `upstream_tag` (p. ej. `v1.46388.2-3`).
Déjalo vacío para empaquetar la última release del origen.

Instalación desde una release publicada:

```bash
TAG=v1.46388.2-3
RPM=claude-desktop-extra-1.46388.2-opensuse3.x86_64.rpm
curl -fsSL -O "https://github.com/albert1t0/claude-desktop-extra-opensuse/releases/download/${TAG}/${RPM}"
sha256sum "$RPM"
sudo zypper --non-interactive --no-gpg-checks install "./${RPM}"
```

El RPM generado **no está firmado**. No hay repositorio OBS/zypper; solo
artefactos en GitHub Releases.

## Requisitos

Instala las herramientas de construcción con los repositorios de openSUSE:

```bash path=null start=null
sudo zypper install rpm-build rpm2cpio cpio tar gzip
```

`rpmbuild`, `rpm`, `rpm2cpio`, `cpio`, `tar` y `sha256sum` deben estar
disponibles en `PATH`.

## Conversión de un RPM Fedora/RHEL

```bash path=null start=null
./scripts/convert-rpm-opensuse.sh \
  /ruta/claude-desktop-extra-1.40609.0-3.x86_64.rpm \
  ./dist \
  opensuse1
```

Se puede verificar el archivo de entrada antes de extraerlo:

```bash path=null start=null
./scripts/convert-rpm-opensuse.sh \
  --sha256 SHA256_PUBLICADO \
  /ruta/claude-desktop-extra-1.40609.0-3.x86_64.rpm \
  ./dist
```

El resultado incluye `dist/rpm-info.txt` con la suma SHA-256 generada.

## Construcción nativa desde tarball

El tarball debe tener la forma `claude-desktop-VERSION-linux.tar.gz` o
`claude-desktop-VERSION-linux-aarch64.tar.gz` y conservar la estructura
upstream (`claude-desktop/`, `launcher/claude-desktop`, `copyright` e
`icons/hicolor`):

```bash path=null start=null
./scripts/build-rpm-opensuse.sh \
  claude-desktop-1.40609.0-linux.tar.gz \
  ./dist \
  opensuse1
```

Para ARM64:

```bash path=null start=null
./scripts/build-rpm-opensuse.sh \
  --arch aarch64 \
  claude-desktop-1.40609.0-linux-aarch64.tar.gz \
  ./dist \
  opensuse1
```

El spec nativo está en
`packaging/claude-desktop-extra-opensuse.spec`; el conversor usa
`packaging/repack-rpm.spec`.

## Validación

```bash path=null start=null
./scripts/validate-rpm.sh ./dist/claude-desktop-extra-*.rpm
./tests/run-tests.sh
```

La validación comprueba que no quedan `mesa-libgbm` ni `libdrm` en los
metadatos, que están presentes los nombres openSUSE y que el RPM contiene el
lanzador, la entrada de escritorio y el árbol Electron.
## Instalación final verificada en openSUSE Tumbleweed

El RPM nativo probado en este proyecto es:

```text
dist-native/claude-desktop-extra-1.40609.0-opensuse1.x86_64.rpm
SHA-256: a24c3f0d1252b649291ace1460300bc6332bc3230e92c57ad865ff6475bc678d
```

Para instalar el artefacto generado:

```bash path=null start=null
RPM="$HOME/GitHub/claude-desktop-extra-opensuse/dist-native/claude-desktop-extra-1.40609.0-opensuse1.x86_64.rpm"
sudo zypper --non-interactive --no-gpg-checks install --oldpackage "$RPM"
```

`--oldpackage` solo es necesario cuando ya está instalada una release superior
del mismo código upstream, como `1.40609.0-3`. En una máquina sin una versión
igual o superior se puede omitir. El RPM generado no está firmado; por eso se
usa `--no-gpg-checks` únicamente después de verificar el checksum y revisar el
artefacto.

Verificación posterior:

```bash path=null start=null
rpm -q claude-desktop-extra
claude-desktop --version
./scripts/validate-rpm.sh "$RPM"
claude-desktop --diagnose
```

La instalación de referencia quedó en `1.40609.0-opensuse1`; el lanzador
respondió `1.40609.0`, el diagnóstico detectó una sesión Wayland/KDE y se
observaron procesos Electron activos. La entrada de menú queda en
`/usr/share/applications/com.anthropic.Claude.desktop`.

### Cowork y dependencias opcionales

Claude Desktop funciona sin instalar componentes adicionales. `--diagnose`
puede indicar `qemu`, firmware OVMF o `virtiofsd` ausentes; eso desactiva
Cowork, pero no impide Chat, Claude Code ni la aplicación principal. Para
habilitar Cowork, instala los paquetes equivalentes disponibles en tu versión
de openSUSE y concede acceso a `/dev/kvm` al usuario; después reinicia Claude.

### Rollback

Para volver a una release superior, instala el RPM upstream o la actualización
del repositorio que corresponda:

```bash path=null start=null
sudo zypper install /ruta/claude-desktop-extra-MAS_NUEVA.x86_64.rpm
```

Para desinstalar el paquete manteniendo la configuración del usuario:

```bash path=null start=null
sudo zypper remove claude-desktop-extra
```

## Instalación opcional

La instalación no forma parte de los scripts de construcción. Después de
revisar el RPM generado, se puede instalar explícitamente:

```bash path=null start=null
sudo zypper install ./dist/claude-desktop-extra-*.rpm
```

El RPM generado no está firmado por este proyecto. Verifica su procedencia y
checksum antes de instalarlo.

## Limitaciones conocidas

- El contenido Electron se conserva tal cual; solo cambian el empaquetado y
  los nombres de dependencias.
- Los nombres de dependencias se basan en openSUSE Tumbleweed y pueden
  requerir ajustes para Leap u otra distribución RPM.
- El spec excluye los binarios incluidos dentro de
  `/usr/lib/claude-desktop` del escaneo automático de dependencias para evitar
  que sus bibliotecas bundled se conviertan en dependencias del sistema.
- El acceso a `/dev/kvm`, QEMU y otros componentes opcionales de Cowork no se
  fuerza como dependencia obligatoria.
