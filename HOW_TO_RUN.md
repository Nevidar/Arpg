# Godot / Nevidar

## Запуск

1. Открой Godot 4.7
2. Import → папка `arpg_Nevidar`
3. Play (F5)

Или из консоли:

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\eilukhin\Documents\Ai_agent\arpg_Nevidar"
```

## Управление

- WASD / стрелки — движение
- ЛКМ — базовый удар
- Q — сплеш (мана)
- E — удар по земле (с 4 уровня)
- Пробел — рывок
- 1–9 — экипировать предмет из инвентаря
- R — рестарт сцены

Подойди к цветному луту на земле, чтобы подобрать.

## Структура

- `scenes/` — арена, игрок, враг
- `scripts/combat/` — статы и формула урона
- `scripts/player/` — воин
- `scripts/enemy/` — 4 типа врагов
- `base/` — замороженные доки, не трогать
