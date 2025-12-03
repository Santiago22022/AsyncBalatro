# AsyncScore

Mod de optimización para Balatro que estabiliza el cálculo de puntuaciones en partidas con muchos jokers y mods pesados.

## Qué hace
- Cachea resultados de manos y jokers para repetir cálculos sin bloquear el juego.
- Decide cuándo activarse según número de jokers y rendimiento reciente.
- Compatibilidad básica con Cryptid y Talisman (incluye detección de modo rápido de Talisman).
- Protección contra fallos: si algo falla, vuelve al cálculo original y deja registro en consola.

## Instalación
1) Copia la carpeta del mod en `%AppData%/Balatro/Mods/AsyncScore/`.
2) Estructura mínima:
```
%AppData%/Balatro/Mods/
├── Steamodded/
├── Talisman/
├── Cryptid/
└── AsyncScore/
    ├── AsyncScore.lua
    ├── AsyncScore.json
    ├── config.lua
    ├── lib/
    └── localization/
```
3) Inicia el juego y activa AsyncScore en el menú de mods.

## Ajustes rápidos
- Async Threshold: jokers necesarios para activar el modo rápido.
- Performance Monitoring: habilita la detección automática de bajadas de FPS.
- Retrigger Optimization: reutiliza efectos seguros cuando las animaciones están desactivadas en Talisman.
- Debug Logging: muestra trazas en consola para diagnósticos.
- Configuración solo en `config.lua`; no hay menú in‑game.
- Optimizaciones siempre activas: no hay espera por umbrales ni detección de rendimiento.

## Notas de estabilidad
- Si otro mod sustituye `calculate_hand` o `calculate_joker` después de AsyncScore, vuelve a cargar los mods para que el hook quede primero.
- El caché se limpia de forma automática con TTL y límite de entradas para evitar fugas de memoria.
