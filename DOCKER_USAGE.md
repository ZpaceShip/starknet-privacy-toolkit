# Docker Usage - Starknet Privacy Toolkit

## Quick Start para Nuevos Usuarios

### 1. Clonar el Repositorio

```bash
git clone https://github.com/ZpaceShip/starknet-privacy-toolkit.git
cd starknet-privacy-toolkit
```

### 2. Construir la Imagen Docker

```bash
docker build -t snt-privacy-toolkit:all-in -f Dockerfile .
```

### 3. Ejecutar el Contenedor

```bash
docker run -it --rm snt-privacy-toolkit:all-in
```

¡Eso es todo! Tendrás acceso a todas las herramientas del toolkit.

---

## Building the Image

El `Dockerfile` ha sido optimizado para ser autosuficiente. Instala todas las dependencias necesarias mediante el script `scripts/setup.sh`:

```bash
docker build -t snt-privacy-toolkit:all-in -f Dockerfile .
```

## Running the Container

### Terminal Interactiva

Para obtener una shell interactiva con todas las herramientas instaladas:

```bash
docker run -it --rm snt-privacy-toolkit:all-in
```

Verás un mensaje de bienvenida que muestra:
- Versiones de Rust, Cargo, Scarb, Noir CLI
- Garaga instalado
- Instrucciones de uso

### Con Volúmenes

Para trabajar con archivos del host:

```bash
docker run -it --rm -v $(pwd):/workspace snt-privacy-toolkit:all-in
```

### Ejecutar Comandos Específicos

```bash
# Verificar versiones
docker run --rm snt-privacy-toolkit:all-in scarb --version
docker run --rm snt-privacy-toolkit:all-in nargo --version

# Ejecutar un comando personalizado
docker run --rm snt-privacy-toolkit:all-in bash -c "make install-all"
```

## Toolchain Instalado

✅ **Rust & Cargo** - Versión 1.91.1  
✅ **Scarb** - v2.9.2  
✅ **Noir CLI** - v1.0.0-beta.1  
✅ **Barretenberg (bb)** - v0.67.0 (automáticamente instalado via bbup)  
✅ **Garaga** - v0.15.5 (Python CLI)  
✅ **Python** - v3.10.12  

Todas las herramientas están configuradas en el PATH global y disponibles al ejecutar el contenedor.  

## Troubleshooting

### Verificar que bb está disponible

```bash
docker run --rm snt-privacy-toolkit:all-in bb --version
# Debe mostrar: 0.67.0
```

Si `bb` no está disponible, intenta reconstruir la imagen sin cache:

```bash
docker build --no-cache -t snt-privacy-toolkit:all-in -f Dockerfile .
```

### npm / Node.js

El contenedor minimista NO incluye Node.js por defecto. Si necesitas npm:

```bash
# Instalación manual dentro del contenedor
docker run -it --rm snt-privacy-toolkit:all-in bash -c "
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && \
  nvm install 22
"
```

## Notas Importantes

### Estructura del Dockerfile

- **Base:** Ubuntu 22.04 minimal
- **PATH Global:** Configurado en `/etc/profile.d/setup-tools.sh`
- **Herramientas:** Instaladas via `scripts/setup.sh` durante el build
- **Entrypoint:** `docker-entrypoint.sh` muestra versiones y abre bash interactivo

### Performance

- Primera construcción: ~90 segundos (descarga y compila dependencias)
- Construcciones posteriores: ~5 segundos (usa cache de Docker)
- Tamaño de imagen: ~3-4 GB (incluye toolchain completo)

### Desarrollo Iterativo

Para desarrollo local sin reconstruir la imagen cada vez:

```bash
# Build una vez
docker build -t snt-privacy-toolkit:all-in -f Dockerfile .

# Luego usa volúmenes para desarrollo
docker run -it --rm \
  -v $(pwd)/src:/workspace/src \
  -v $(pwd)/donation_badge_verifier:/workspace/donation_badge_verifier \
  snt-privacy-toolkit:all-in
```

### Limpiar Recursos

```bash
# Eliminar imagen
docker rmi snt-privacy-toolkit:all-in

# Eliminar volúmenes no usados
docker volume prune

# Limpiar todo (imágenes, contenedores, volúmenes, cache)
docker system prune -a --volumes
```

## Verificar Instalación

```bash
docker run --rm snt-privacy-toolkit:all-in bash -c "
  echo '=== Toolchain Versions ==='
  rustc --version
  scarb --version
  nargo --version
  bb --version
  python3 -c 'import garaga; print(f\"Garaga: installed\")'
"
```

## Comandos Útiles

### Ver todas las versiones al iniciar

```bash
docker run -it --rm snt-privacy-toolkit:all-in
# Automáticamente muestra:
# - Rust, Cargo, Scarb, Noir, bb, Garaga, Python versions
# - Instrucciones de uso
```

### Compilar un proyecto Cairo

```bash
docker run -it --rm -v $(pwd)/projects:/workspace snt-privacy-toolkit:all-in bash -c "
  cd /workspace/my-project
  scarb build
"
```

### Crear y deployar una cuenta

```bash
docker run -it --rm -v $(pwd):/workspace snt-privacy-toolkit:all-in bash
# Dentro del contenedor:
cd /workspace
make account-create
make account-deploy
exit
```

### Ejecutar make targets

```bash
# Verificar toolchain
docker run --rm snt-privacy-toolkit:all-in make install-all

# Crear cuenta (requiere volumen montado)
docker run -it --rm -v $(pwd):/workspace snt-privacy-toolkit:all-in make account-create

# Deployar cuenta
docker run -it --rm -v $(pwd):/workspace snt-privacy-toolkit:all-in make account-deploy
```
