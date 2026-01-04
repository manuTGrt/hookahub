# 🖼️ Gestor de Imágenes de Tabacos

Script automatizado para buscar, descargar, optimizar y subir imágenes de tabacos a Supabase Storage.

## 📋 Características

✅ **Búsqueda automática** en múltiples fuentes (Google, Unsplash)  
✅ **Optimización inteligente** (redimensionado, conversión a WebP)  
✅ **Procesamiento paralelo** por lotes para máxima eficiencia  
✅ **Manejo robusto de errores** con logs detallados  
✅ **Actualización automática** de la base de datos  

---

## 🚀 Instalación

### 1. Instalar Python 3.8+

Verifica que tienes Python instalado:
```bash
python --version
```

### 2. Instalar dependencias

```bash
cd scripts
pip install -r requirements.txt
```

### 3. Configurar variables de entorno

Copia el archivo de ejemplo:
```bash
copy .env.example .env
```

Edita `.env` y completa:
```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_KEY=tu_service_role_key
```

**⚠️ IMPORTANTE:** Usa la **Service Role Key** (no la anon key) para tener permisos completos.

#### Configuración Opcional (APIs de imágenes)

Para mejor calidad de resultados, configura estas APIs:

**Google Custom Search API** (Recomendado):
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un proyecto y habilita "Custom Search API"
3. Genera una API key
4. Crea un Custom Search Engine en [cse.google.com](https://cse.google.com/)
5. Agrega las credenciales al `.env`

**Unsplash API** (Para fotos de stock):
1. Crea cuenta en [Unsplash Developers](https://unsplash.com/developers)
2. Registra una aplicación
3. Copia tu Access Key al `.env`

---

## 💻 Uso

### Modo Prueba (Recomendado para empezar)

Procesa solo 10 tabacos para verificar que todo funciona:

```bash
python tobacco_image_manager.py --test --limit 10
```

### Procesar una marca específica

```bash
python tobacco_image_manager.py --brand "Al Fakher"
python tobacco_image_manager.py --brand "Adalya"
```

### Procesar todos los tabacos

```bash
python tobacco_image_manager.py --full
```

### Opciones avanzadas

```bash
# Procesar 50 tabacos con lotes de 10
python tobacco_image_manager.py --limit 50 --batch-size 10

# Combinar filtros
python tobacco_image_manager.py --brand "Starbuzz" --limit 20
```

---

## 📊 Parámetros

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `--test` | Modo prueba (procesa 10 registros) | `--test` |
| `--limit N` | Limita a N tabacos | `--limit 50` |
| `--brand "X"` | Solo procesa marca X | `--brand "Al Fakher"` |
| `--full` | Procesa todos sin imagen | `--full` |
| `--batch-size N` | Tamaño de lote paralelo (default: 5) | `--batch-size 10` |

---

## 📈 Salida del Script

El script genera:

1. **Logs en consola** con progreso en tiempo real
2. **Archivo de log** con timestamp: `tobacco_images_YYYYMMDD_HHMMSS.log`
3. **Resumen final** con estadísticas:
   - Total procesados
   - Éxitos / Fallos
   - Tabacos sin imagen encontrada
   - Lista de errores

### Ejemplo de salida:

```
============================================================
🚀 Iniciando procesamiento de 100 tabacos
📦 Tamaño de lote: 5
============================================================

🔍 Procesando: Al Fakher - Mint
🔗 Imagen encontrada: https://example.com/image.jpg
✅ Imagen optimizada: 245678 → 89234 bytes (36.3%)
📤 Subiendo a: by-brand/al-fakher/mint.webp
✅ ÉXITO: Al Fakher - Mint

📈 Progreso: 5/100 | ✅ 4 | ❌ 0 | ⚠️ 1

...

============================================================
📊 RESUMEN FINAL
============================================================
Total procesados: 100
✅ Éxitos: 87 (87.0%)
❌ Fallos: 5
⚠️ Sin imagen: 8
============================================================
```

---

## 🔧 Troubleshooting

### Error: "Faltan dependencias"

```bash
pip install supabase pillow python-dotenv aiohttp
```

### Error: "No se encontraron imágenes"

- Verifica que configuraste las APIs (Google/Unsplash)
- Sin APIs configuradas, el script solo puede usar placeholder
- Considera añadir manualmente las primeras imágenes

### Error: "Permission denied" en Supabase

- Verifica que usas **Service Role Key** (no anon key)
- Verifica que el bucket existe y es público
- Revisa las políticas RLS del bucket

### Imágenes de baja calidad

- Configura Google Custom Search API para mejores resultados
- Ajusta los parámetros `max_size` y `quality` en el código
- Considera fuentes adicionales específicas de shisha

---

## 🎯 Optimizaciones

### Rendimiento

- **Lotes paralelos**: Procesa múltiples tabacos simultáneamente
- **Caché local**: Las imágenes ya procesadas no se vuelven a descargar
- **Timeouts**: Evita bloqueos en descargas lentas

### Calidad

- **WebP format**: 30% menos peso que JPG con igual calidad
- **Redimensionado**: Tamaño máximo 800x800px (configurable)
- **Compresión**: Quality 85 (balance entre calidad y tamaño)

### Costos

- **Almacenamiento**: ~81MB para 810 imágenes @ 100KB promedio
- **Transferencia**: Incluido en plan gratuito de Supabase
- **APIs**: Google/Unsplash tienen planes gratuitos generosos

---

## 📝 Notas

- El script **nunca sobrescribe** imágenes existentes (salvo con `upsert: true`)
- Los logs se guardan automáticamente con timestamp
- Se aplica pausa de 2s entre lotes para respetar rate limits
- Las imágenes se organizan por marca en carpetas

---

## 🔐 Seguridad

⚠️ **NUNCA** compartas tu Service Role Key  
⚠️ NO incluyas `.env` en el control de versiones  
⚠️ Usa variables de entorno en producción  

El archivo `.env` ya está en `.gitignore` por seguridad.

---

## 📞 Soporte

Si encuentras problemas:

1. Revisa los logs generados
2. Verifica las credenciales en `.env`
3. Asegúrate de tener permisos en Supabase
4. Revisa la documentación de las APIs usadas

---

## 🚀 Próximos Pasos

Después de ejecutar el script:

1. Verifica las imágenes en Supabase Storage
2. Prueba la app Flutter para ver los cambios
3. Revisa el log para tabacos sin imagen
4. Considera añadir manualmente las imágenes faltantes

---

**Creado para Hookahub** 🔥
