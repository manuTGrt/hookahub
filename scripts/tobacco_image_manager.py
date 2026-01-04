"""
Script para automatizar la obtención y subida de imágenes de tabacos a Supabase.
Busca imágenes en múltiples fuentes y las sube al bucket 'tobacco-images'.

Uso:
    python tobacco_image_manager.py --test --limit 10  # Probar con 10 tabacos
    python tobacco_image_manager.py --brand "Al Fakher"  # Procesar una marca
    python tobacco_image_manager.py --full  # Procesar todos
"""

import asyncio
import aiohttp
import os
import sys
import io
import argparse
import logging
from pathlib import Path
from typing import Optional, Dict, List
from datetime import datetime

try:
    from supabase import create_client, Client
    from PIL import Image
    from dotenv import load_dotenv
except ImportError:
    print("❌ Error: Faltan dependencias. Instala con:")
    print("   pip install supabase pillow python-dotenv aiohttp")
    sys.exit(1)


# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'tobacco_images_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class TobaccoImageManager:
    """Gestor de imágenes de tabacos para Supabase"""
    
    def __init__(self, supabase_url: str, supabase_key: str):
        """
        Inicializa el gestor con las credenciales de Supabase.
        
        Args:
            supabase_url: URL del proyecto Supabase
            supabase_key: Service role key (con permisos de admin)
        """
        self.supabase: Client = create_client(supabase_url, supabase_key)
        self.bucket_name = 'tobacco-images'
        self.stats = {
            'total': 0,
            'success': 0,
            'failed': 0,
            'no_image': 0,
            'errors': []
        }
        
    async def fetch_tobaccos(
        self, 
        brand: Optional[str] = None, 
        limit: Optional[int] = None,
        only_without_image: bool = True
    ) -> List[Dict]:
        """
        Obtiene tabacos de la base de datos.
        
        Args:
            brand: Filtrar por marca específica
            limit: Límite de registros a obtener
            only_without_image: Solo tabacos sin imagen
            
        Returns:
            Lista de diccionarios con datos de tabacos
        """
        try:
            query = self.supabase.table('tobaccos').select('id, name, brand, image_url')
            
            if only_without_image:
                query = query.is_('image_url', 'null')
            
            if brand:
                query = query.eq('brand', brand)
            
            if limit:
                query = query.limit(limit)
                
            response = query.execute()
            logger.info(f"📊 Obtenidos {len(response.data)} tabacos de la BD")
            return response.data
            
        except Exception as e:
            logger.error(f"❌ Error al obtener tabacos: {str(e)}")
            return []
    
    async def search_image_google(self, brand: str, name: str) -> Optional[str]:
        """
        Busca imagen usando Google Custom Search API.
        Requiere API key y Search Engine ID configurados.
        
        Args:
            brand: Marca del tabaco
            name: Nombre del tabaco
            
        Returns:
            URL de la imagen o None
        """
        # TODO: Implementar con Google Custom Search API
        # Requiere:
        # - GOOGLE_API_KEY en .env
        # - GOOGLE_SEARCH_ENGINE_ID en .env
        
        api_key = os.getenv('GOOGLE_API_KEY')
        search_engine_id = os.getenv('GOOGLE_SEARCH_ENGINE_ID')
        
        if not api_key or not search_engine_id:
            logger.warning("⚠️  Google API no configurada. Configura GOOGLE_API_KEY y GOOGLE_SEARCH_ENGINE_ID en .env")
            return None
        
        search_query = f"{brand} {name} hookah tobacco shisha"
        url = "https://www.googleapis.com/customsearch/v1"
        
        params = {
            'key': api_key,
            'cx': search_engine_id,
            'q': search_query,
            'searchType': 'image',
            'num': 3,  # Obtener 3 resultados
            'imgSize': 'large',
            'safe': 'active'
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as resp:
                    if resp.status != 200:
                        logger.warning(f"⚠️  Google Search falló: {resp.status}")
                        return None
                    
                    data = await resp.json()
                    items = data.get('items', [])
                    
                    if items:
                        # Retornar la URL de la primera imagen
                        return items[0]['link']
                        
        except Exception as e:
            logger.warning(f"⚠️  Error en Google Search: {str(e)}")
            
        return None
    
    async def search_image_unsplash(self, brand: str, name: str) -> Optional[str]:
        """
        Busca imagen en Unsplash (fotos de stock).
        Útil como fallback cuando no hay fotos específicas.
        
        Args:
            brand: Marca del tabaco
            name: Nombre del tabaco
            
        Returns:
            URL de la imagen o None
        """
        api_key = os.getenv('UNSPLASH_ACCESS_KEY')
        
        if not api_key:
            return None
        
        # Buscar términos generales relacionados con shisha
        search_terms = ['hookah', 'shisha', 'tobacco', 'smoking']
        url = "https://api.unsplash.com/search/photos"
        
        params = {
            'query': f"{brand} {name} hookah",
            'per_page': 1,
            'orientation': 'squarish'
        }
        
        headers = {'Authorization': f'Client-ID {api_key}'}
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params, headers=headers) as resp:
                    if resp.status != 200:
                        return None
                    
                    data = await resp.json()
                    results = data.get('results', [])
                    
                    if results:
                        return results[0]['urls']['regular']
                        
        except Exception as e:
            logger.warning(f"⚠️  Error en Unsplash: {str(e)}")
            
        return None
    
    async def download_and_optimize_image(
        self, 
        image_url: str, 
        max_size: int = 800,
        quality: int = 85
    ) -> Optional[bytes]:
        """
        Descarga y optimiza una imagen.
        
        Args:
            image_url: URL de la imagen a descargar
            max_size: Tamaño máximo en píxeles (ancho/alto)
            quality: Calidad de compresión (0-100)
            
        Returns:
            Bytes de la imagen optimizada en formato WebP o None si falla
        """
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(image_url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
                    if resp.status != 200:
                        logger.warning(f"⚠️  No se pudo descargar imagen: HTTP {resp.status}")
                        return None
                    
                    # Verificar tipo de contenido
                    content_type = resp.headers.get('Content-Type', '')
                    if not content_type.startswith('image/'):
                        logger.warning(f"⚠️  Contenido no es imagen: {content_type}")
                        return None
                    
                    image_data = await resp.read()
                    
                    # Abrir imagen con PIL
                    img = Image.open(io.BytesIO(image_data))
                    
                    # Convertir a RGB si es necesario (para WebP)
                    if img.mode in ('RGBA', 'LA', 'P'):
                        background = Image.new('RGB', img.size, (255, 255, 255))
                        if img.mode == 'P':
                            img = img.convert('RGBA')
                        background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                        img = background
                    elif img.mode != 'RGB':
                        img = img.convert('RGB')
                    
                    # Redimensionar manteniendo proporción
                    img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
                    
                    # Convertir a WebP (mejor compresión)
                    output = io.BytesIO()
                    img.save(output, format='WEBP', quality=quality, method=6)
                    output.seek(0)
                    
                    optimized_data = output.getvalue()
                    logger.info(f"✅ Imagen optimizada: {len(image_data)} → {len(optimized_data)} bytes "
                               f"({len(optimized_data)/len(image_data)*100:.1f}%)")
                    
                    return optimized_data
                    
        except Exception as e:
            logger.error(f"❌ Error al procesar imagen: {str(e)}")
            return None
    
    def sanitize_filename(self, text: str) -> str:
        """Sanitiza texto para usar como nombre de archivo"""
        # Convertir a minúsculas y reemplazar espacios
        text = text.lower().strip()
        # Caracteres permitidos: letras, números, guiones
        allowed = 'abcdefghijklmnopqrstuvwxyz0123456789- '
        text = ''.join(c if c in allowed else '' for c in text)
        # Reemplazar múltiples espacios por uno solo
        text = ' '.join(text.split())
        # Reemplazar espacios por guiones
        text = text.replace(' ', '-')
        return text
    
    async def upload_to_supabase(
        self, 
        tobacco_id: str, 
        brand: str, 
        name: str, 
        image_data: bytes
    ) -> Optional[str]:
        """
        Sube imagen a Supabase Storage y actualiza la BD.
        
        Args:
            tobacco_id: ID del tabaco en la BD
            brand: Marca del tabaco
            name: Nombre del tabaco
            image_data: Datos binarios de la imagen
            
        Returns:
            URL pública de la imagen o None si falla
        """
        try:
            # Crear path estructurado por marca
            safe_brand = self.sanitize_filename(brand)
            safe_name = self.sanitize_filename(name)
            file_path = f"by-brand/{safe_brand}/{safe_name}.webp"
            
            logger.info(f"📤 Subiendo a: {file_path}")
            
            # Subir a Storage
            self.supabase.storage.from_(self.bucket_name).upload(
                file_path, 
                image_data,
                file_options={"content-type": "image/webp", "upsert": "true"}
            )
            
            # Obtener URL pública
            public_url = self.supabase.storage.from_(self.bucket_name).get_public_url(file_path)
            
            # Actualizar registro en BD
            self.supabase.table('tobaccos').update({
                'image_url': public_url
            }).eq('id', tobacco_id).execute()
            
            logger.info(f"✅ URL pública: {public_url}")
            return public_url
            
        except Exception as e:
            logger.error(f"❌ Error al subir a Supabase: {str(e)}")
            return None
    
    async def process_tobacco(self, tobacco: Dict) -> bool:
        """
        Procesa un tabaco completo: buscar imagen, descargar, optimizar y subir.
        
        Args:
            tobacco: Diccionario con datos del tabaco
            
        Returns:
            True si se procesó exitosamente, False en caso contrario
        """
        tobacco_id = tobacco['id']
        brand = tobacco['brand']
        name = tobacco['name']
        
        logger.info(f"\n{'='*60}")
        logger.info(f"🔍 Procesando: {brand} - {name}")
        
        try:
            # 1. Buscar imagen (intentar múltiples fuentes)
            image_url = None
            
            # Intentar Google primero
            image_url = await self.search_image_google(brand, name)
            
            # Si no hay resultado, intentar Unsplash
            if not image_url:
                image_url = await self.search_image_unsplash(brand, name)
            
            if not image_url:
                logger.warning(f"⚠️  No se encontró imagen para: {brand} - {name}")
                self.stats['no_image'] += 1
                return False
            
            logger.info(f"🔗 Imagen encontrada: {image_url[:80]}...")
            
            # 2. Descargar y optimizar
            image_data = await self.download_and_optimize_image(image_url)
            
            if not image_data:
                logger.warning(f"⚠️  No se pudo descargar/optimizar: {brand} - {name}")
                self.stats['failed'] += 1
                return False
            
            # 3. Subir a Supabase
            public_url = await self.upload_to_supabase(
                tobacco_id,
                brand,
                name,
                image_data
            )
            
            if not public_url:
                logger.error(f"❌ No se pudo subir: {brand} - {name}")
                self.stats['failed'] += 1
                return False
            
            logger.info(f"✅ ÉXITO: {brand} - {name}")
            self.stats['success'] += 1
            return True
            
        except Exception as e:
            error_msg = f"Error en {brand} - {name}: {str(e)}"
            logger.error(f"❌ {error_msg}")
            self.stats['errors'].append(error_msg)
            self.stats['failed'] += 1
            return False
    
    async def bulk_process(
        self, 
        brand: Optional[str] = None,
        limit: Optional[int] = None,
        batch_size: int = 5
    ):
        """
        Procesa múltiples tabacos en lotes.
        
        Args:
            brand: Filtrar por marca específica
            limit: Límite de tabacos a procesar
            batch_size: Número de tabacos a procesar simultáneamente
        """
        # Obtener tabacos
        tobaccos = await self.fetch_tobaccos(brand=brand, limit=limit)
        
        if not tobaccos:
            logger.info("ℹ️  No hay tabacos para procesar")
            return
        
        self.stats['total'] = len(tobaccos)
        
        logger.info(f"\n{'='*60}")
        logger.info(f"🚀 Iniciando procesamiento de {self.stats['total']} tabacos")
        logger.info(f"📦 Tamaño de lote: {batch_size}")
        logger.info(f"{'='*60}\n")
        
        # Procesar en lotes
        for i in range(0, len(tobaccos), batch_size):
            batch = tobaccos[i:i+batch_size]
            
            logger.info(f"\n📦 Procesando lote {i//batch_size + 1} ({len(batch)} tabacos)")
            
            # Procesar lote en paralelo
            tasks = [self.process_tobacco(t) for t in batch]
            await asyncio.gather(*tasks)
            
            # Mostrar progreso
            processed = min(i + batch_size, len(tobaccos))
            logger.info(f"\n📈 Progreso: {processed}/{self.stats['total']} | "
                       f"✅ {self.stats['success']} | "
                       f"❌ {self.stats['failed']} | "
                       f"⚠️  {self.stats['no_image']}")
            
            # Pausa entre lotes para evitar rate limits
            if i + batch_size < len(tobaccos):
                logger.info("⏸️  Pausa de 2 segundos...")
                await asyncio.sleep(2)
        
        # Resumen final
        self.print_summary()
    
    def print_summary(self):
        """Imprime resumen del procesamiento"""
        logger.info(f"\n{'='*60}")
        logger.info(f"📊 RESUMEN FINAL")
        logger.info(f"{'='*60}")
        logger.info(f"Total procesados: {self.stats['total']}")
        logger.info(f"✅ Éxitos: {self.stats['success']} ({self.stats['success']/max(self.stats['total'],1)*100:.1f}%)")
        logger.info(f"❌ Fallos: {self.stats['failed']}")
        logger.info(f"⚠️  Sin imagen: {self.stats['no_image']}")
        
        if self.stats['errors']:
            logger.info(f"\n🔴 Errores detectados ({len(self.stats['errors'])}):")
            for error in self.stats['errors'][:10]:  # Mostrar solo primeros 10
                logger.info(f"  - {error}")
            if len(self.stats['errors']) > 10:
                logger.info(f"  ... y {len(self.stats['errors']) - 10} más")
        
        logger.info(f"{'='*60}\n")


async def main():
    """Función principal"""
    parser = argparse.ArgumentParser(
        description='Gestor de imágenes de tabacos para Supabase',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  python tobacco_image_manager.py --test --limit 10
  python tobacco_image_manager.py --brand "Al Fakher"
  python tobacco_image_manager.py --full
        """
    )
    
    parser.add_argument('--test', action='store_true', 
                       help='Modo prueba (procesa pocos registros)')
    parser.add_argument('--limit', type=int, 
                       help='Límite de tabacos a procesar')
    parser.add_argument('--brand', type=str, 
                       help='Procesar solo una marca específica')
    parser.add_argument('--full', action='store_true', 
                       help='Procesar todos los tabacos sin imagen')
    parser.add_argument('--batch-size', type=int, default=5,
                       help='Tamaño del lote de procesamiento paralelo (default: 5)')
    
    args = parser.parse_args()
    
    # Cargar variables de entorno
    load_dotenv()
    
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_key = os.getenv('SUPABASE_SERVICE_KEY') or os.getenv('SUPABASE_ANON_KEY')
    
    if not supabase_url or not supabase_key:
        logger.error("❌ Error: Configura SUPABASE_URL y SUPABASE_SERVICE_KEY en .env")
        sys.exit(1)
    
    # Crear gestor
    manager = TobaccoImageManager(supabase_url, supabase_key)
    
    # Determinar parámetros
    limit = args.limit
    if args.test and not limit:
        limit = 10
    
    # Ejecutar
    await manager.bulk_process(
        brand=args.brand,
        limit=limit,
        batch_size=args.batch_size
    )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("\n\n⚠️  Proceso interrumpido por el usuario")
        sys.exit(0)
